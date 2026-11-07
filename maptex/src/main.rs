//! xc3_maptex - Kartentexturen (.wismhd/.wismda) von Xenoblade Chronicles 3 exportieren und ersetzen.
//! Die .wismhd wird nicht neu geschrieben, sondern nur an den Textur-Eintraegen gepatcht.
//! Neue Texturdaten werden ans Ende der .wismda angehaengt (Originaldaten bleiben unberuehrt).
use anyhow::{Context, Result, anyhow, bail};
use rayon::prelude::*;
use std::io::{Cursor, Read, Seek, SeekFrom};
use std::path::{Path, PathBuf};
use xc3_lib::dds::DdsExt;
use xc3_lib::mibl::Mibl;
use xc3_lib::msmd::{Msmd, MsmdInner, MsmdV112};
use xc3_lib::xbc1::{CompressionType, Xbc1};

fn main() {
    if let Err(e) = run() {
        eprintln!("Fehler: {e:?}");
        std::process::exit(1);
    }
}

fn run() -> Result<()> {
    let a: Vec<String> = std::env::args().collect();
    match a.get(1).map(|s| s.as_str()) {
        Some("info") => info(&a[2]),
        Some("export") => export(&a[2], &a[3]),
        Some("import") => import(&a[2], &a[3], &a[4]),
        _ => bail!(
            "xc3_maptex info <map.wismhd>\n\
             xc3_maptex export <map.wismhd> <ordner>          (DDS: <map>.<index>.dds)\n\
             xc3_maptex import <map.wismhd> <ordner> <ausgabeordner>"
        ),
    }
}

struct Map {
    msmd: MsmdV112,
    wismda: Vec<u8>,
    compressed: bool,
}

fn load(wismhd: &str) -> Result<Map> {
    let msmd = Msmd::from_file(wismhd).with_context(|| format!("{wismhd} ist keine gueltige .wismhd"))?;
    let MsmdInner::V112(msmd) = msmd.inner else { bail!("nicht unterstuetzte Kartenversion") };
    let wismda = std::fs::read(Path::new(wismhd).with_extension("wismda")).context(".wismda nicht lesbar")?;
    let compressed = msmd.wismda_info.compressed_length != msmd.wismda_info.decompressed_length;
    Ok(Map { msmd, wismda, compressed })
}

fn stem(p: &str) -> String {
    Path::new(p).file_stem().unwrap().to_string_lossy().to_string()
}

fn info(wismhd: &str) -> Result<()> {
    let m = load(wismhd)?;
    let i = &m.msmd.wismda_info;
    println!("wismda {} Bytes, info: comp {} unk1 {} decomp {} streambuf {}", m.wismda.len(), i.compressed_length, i.unk1, i.decompressed_length, i.streaming_buffer_length);
    println!("{} Texturen, komprimiert: {}", m.msmd.textures.len(), m.compressed);
    Ok(())
}

fn full_surface(m: &Map, t: &xc3_lib::msmd::Texture) -> Result<image_dds::Surface<Vec<u8>>> {
    let mut r = Cursor::new(&m.wismda);
    let mid: Mibl = t.mid.extract(&mut r, m.compressed)?;
    if t.base_mip.decompressed_size > 0 {
        let base = t.base_mip.decompress(&mut r, m.compressed)?;
        mid.to_surface_with_base_mip(&base).map_err(|e| anyhow!("{e:?}"))
    } else {
        mid.to_surface().map_err(|e| anyhow!("{e:?}"))
    }
}

fn export(wismhd: &str, out: &str) -> Result<()> {
    let m = load(wismhd)?;
    std::fs::create_dir_all(out)?;
    let name = stem(wismhd);
    let n: usize = m.msmd.textures.par_iter().enumerate().map(|(i, t)| -> usize {
        let path = Path::new(out).join(format!("{name}.{i}.dds"));
        match full_surface(&m, t).and_then(|s| s.to_dds().map_err(|e| anyhow!("{e:?}"))).and_then(|d| d.save(&path).map_err(|e| anyhow!("{e:?}"))) {
            Ok(_) => 1,
            Err(e) => { eprintln!("Textur {i}: {e}"); 0 }
        }
    }).sum();
    println!("{n} Texturen exportiert");
    Ok(())
}

fn find_unique(hay: &[u8], needle: &[u8]) -> Result<usize> {
    let mut hits = hay.windows(needle.len()).enumerate().filter(|(_, w)| *w == needle).map(|(i, _)| i);
    let first = hits.next().ok_or_else(|| anyhow!("Muster nicht gefunden"))?;
    if hits.next().is_some() { bail!("Muster nicht eindeutig") }
    Ok(first)
}

fn u32s(v: &[u32]) -> Vec<u8> { v.iter().flat_map(|x| x.to_le_bytes()).collect() }

fn xbc1_name(wismda: &[u8], offset: u32) -> String {
    let mut r = Cursor::new(wismda);
    r.seek(SeekFrom::Start(offset as u64)).ok();
    Xbc1::read(&mut r).map(|x| x.name).unwrap_or_default()
}

fn import(wismhd: &str, folder: &str, outdir: &str) -> Result<()> {
    let m = load(wismhd)?;
    let mut hd = std::fs::read(wismhd)?;
    let name = stem(wismhd);
    let texs = &m.msmd.textures;

    // Position der Textur-Tabelle in der .wismhd finden (20 Bytes pro Eintrag)
    let t0 = &texs[0];
    let pat = u32s(&[t0.mid.offset, t0.mid.decompressed_size, t0.base_mip.offset, t0.base_mip.decompressed_size, t0.flags]);
    let table = find_unique(&hd, &pat).context("Textur-Tabelle")?;
    for (i, t) in texs.iter().enumerate() {
        let p = table + 20 * i;
        let e = u32s(&[t.mid.offset, t.mid.decompressed_size, t.base_mip.offset, t.base_mip.decompressed_size, t.flags]);
        if hd[p..p + 20] != e[..] { bail!("Textur-Tabelle passt nicht bei Eintrag {i}") }
    }
    let wi = &m.msmd.wismda_info;
    let info_pos = find_unique(&hd, &u32s(&[wi.compressed_length, wi.unk1, wi.decompressed_length, wi.streaming_buffer_length])).context("WismdaInfo")?;

    // Ersatz-DDS einsammeln: <map>.<index>[.irgendwas].dds
    let mut repl: Vec<(usize, PathBuf)> = Vec::new();
    for e in std::fs::read_dir(folder)? {
        let p = e?.path();
        if p.extension().map(|x| x != "dds").unwrap_or(true) { continue }
        let f = p.file_stem().unwrap().to_string_lossy().to_string();
        let mut parts = f.split('.');
        if parts.next() != Some(&name) { continue }
        if let Some(Ok(i)) = parts.next().map(|s| s.parse::<usize>()) { if i < texs.len() { repl.push((i, p)); } }
    }
    repl.sort();
    println!("{} Ersatz-Texturen gefunden", repl.len());

    // Neue Daten parallel erzeugen
    let built: Vec<(usize, Vec<u8>, u32, Option<(Vec<u8>, u32)>)> = repl.par_iter().filter_map(|(i, p)| {
        let r = (|| -> Result<_> {
            let t = &texs[*i];
            let dds = image_dds::ddsfile::Dds::from_file(p).map_err(|e| anyhow!("{e:?}"))?;
            let mibl = Mibl::from_dds(&dds).map_err(|e| anyhow!("{e:?}"))?;
            let orig: Mibl = t.mid.extract(&mut Cursor::new(&m.wismda), m.compressed)?;
            if mibl.footer.image_format != orig.footer.image_format { bail!("Format {:?} statt {:?}", mibl.footer.image_format, orig.footer.image_format) }
            let comp = |bytes: &[u8], off: u32| -> Result<Vec<u8>> {
                let x = Xbc1::from_decompressed(xbc1_name(&m.wismda, off), bytes, CompressionType::Zlib)?;
                Ok(x.to_bytes()?)
            };
            if t.base_mip.decompressed_size > 0 {
                let (mid, base) = mibl.split_base_mip();
                let mid_bytes = mid.to_bytes()?;
                Ok((*i, comp(&mid_bytes, t.mid.offset)?, mid_bytes.len() as u32, Some((comp(&base, t.base_mip.offset)?, base.len() as u32))))
            } else {
                let b = mibl.to_bytes()?;
                Ok((*i, comp(&b, t.mid.offset)?, b.len() as u32, None))
            }
        })();
        match r { Ok(x) => Some(x), Err(e) => { eprintln!("Textur {i}: {e}"); None } }
    }).collect();

    // Anhaengen + Tabelle patchen
    let mut da = m.wismda.clone();
    let mut extra_decomp: i64 = 0;
    let append = |da: &mut Vec<u8>, bytes: &[u8]| -> u32 {
        while da.len() % 16 != 0 { da.push(0) }
        let off = da.len() as u32;
        da.extend_from_slice(bytes);
        off
    };
    for (i, mid_x, mid_size, base) in &built {
        let t = &texs[*i];
        let p = table + 20 * i;
        let mo = append(&mut da, mid_x);
        hd[p..p + 8].copy_from_slice(&u32s(&[mo, *mid_size]));
        extra_decomp += *mid_size as i64 - t.mid.decompressed_size as i64;
        if let Some((bx, bs)) = base {
            let bo = append(&mut da, bx);
            hd[p + 8..p + 16].copy_from_slice(&u32s(&[bo, *bs]));
            extra_decomp += *bs as i64 - t.base_mip.decompressed_size as i64;
        }
    }
    while da.len() % 16 != 0 { da.push(0) }
    if da.len() > u32::MAX as usize { bail!(".wismda waere groesser als 4 GB") }
    let new_decomp = (wi.decompressed_length as i64 + extra_decomp) as u32;
    hd[info_pos..info_pos + 12].copy_from_slice(&u32s(&[da.len() as u32, wi.unk1, new_decomp]));

    std::fs::create_dir_all(outdir)?;
    let out_hd = Path::new(outdir).join(format!("{name}.wismhd"));
    std::fs::write(&out_hd, &hd)?;
    std::fs::write(out_hd.with_extension("wismda"), &da)?;
    println!("{} Texturen ersetzt -> {}", built.len(), out_hd.display());

    // Kontrolle: neu laden und ersetzte Texturen dekodieren
    let chk = load(out_hd.to_str().unwrap())?;
    for (i, _, _, _) in &built {
        let s = full_surface(&chk, &chk.msmd.textures[*i]).with_context(|| format!("Kontrolle Textur {i}"))?;
        let _ = s;
    }
    println!("Kontrolle ok");
    Ok(())
}
