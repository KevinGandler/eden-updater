// Eden Updater - portabler EXE-Starter
// Bettet EdenUpdater.ps1 ein und fuehrt es in Windows PowerShell 5.1 aus
// (STA, gleicher Thread, kein Konsolenfenster).
using System;
using System.Collections;
using System.IO;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

[assembly: AssemblyTitle("Eden Updater")]
[assembly: AssemblyProduct("Eden Updater")]
[assembly: AssemblyDescription("Eden Nightly Updater")]
[assembly: AssemblyCompany("")]
[assembly: AssemblyCopyright("")]
[assembly: AssemblyVersion("1.1.3.0")]
[assembly: AssemblyFileVersion("1.1.3.0")]

// Faerbt die Windows-Titelleiste und den Fensterrahmen im Theme. Das Skript nutzt diese Klasse direkt;
// laeuft es ohne EXE, uebersetzt es sich dieselbe Klasse selbst (siehe src/05-themes-dialoge.ps1).
public static class DwmTheme
{
    [DllImport("dwmapi.dll")]
    private static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int val, int size);
    public static void Apply(IntPtr hwnd, bool dark, int caption, int border, int text)
    {
        int d = dark ? 1 : 0;
        DwmSetWindowAttribute(hwnd, 20, ref d, 4);       // dunkle Titelleiste (Win10 20H1+ / Win11)
        DwmSetWindowAttribute(hwnd, 19, ref d, 4);       // aeltere Win10-Builds
        DwmSetWindowAttribute(hwnd, 35, ref caption, 4); // Titelleistenfarbe (Win11)
        DwmSetWindowAttribute(hwnd, 34, ref border, 4);  // Rahmenfarbe (Win11)
        DwmSetWindowAttribute(hwnd, 36, ref text, 4);    // Titeltext (Win11)
    }
}

// Schleifen, die im Skript beim Start spuerbar Zeit kosten, fertig uebersetzt. Das Skript nutzt sie nur,
// wenn es aus der EXE laeuft; als reines Skript (Tests) rechnet es dasselbe selbst.
public static class EdenNative
{
    // Sprachtext mit einer Zeile "Schluessel=Text" je Eintrag -> Tabelle (\n im Text = Zeilenumbruch)
    public static Hashtable ParseLang(string txt)
    {
        Hashtable h = new Hashtable(StringComparer.CurrentCultureIgnoreCase);
        if (txt == null) return h;
        foreach (string raw in txt.Split('\n'))
        {
            string line = raw.TrimEnd('\r');
            int i = line.IndexOf('=');
            if (i < 1 || line.StartsWith("#", StringComparison.Ordinal)) continue;
            h[line.Substring(0, i).Trim()] = line.Substring(i + 1).TrimEnd().Replace("\\n", "\n");
        }
        return h;
    }

    // Eintraege von source nach target uebernehmen (vorhandene werden ersetzt)
    public static void Merge(IDictionary target, IDictionary source)
    {
        foreach (DictionaryEntry e in source) target[e.Key] = e.Value;
    }

    // Texte als Ressourcen ablegen: Schluessel "prefix + Name", Wert als Text
    public static void Fill(IDictionary target, IDictionary source, string prefix)
    {
        foreach (DictionaryEntry e in source) target[prefix + Convert.ToString(e.Key)] = Convert.ToString(e.Value);
    }

    // Benannte Elemente eines Fensters heraussuchen (ruft dessen FindName auf)
    public static Hashtable FindNames(object root, string[] names)
    {
        Hashtable h = new Hashtable(StringComparer.CurrentCultureIgnoreCase);
        MethodInfo m = root.GetType().GetMethod("FindName", new Type[] { typeof(string) });
        foreach (string n in names) h[n] = m.Invoke(root, new object[] { n });
        return h;
    }
}

static class Program
{
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    static extern int MessageBoxW(IntPtr hWnd, string text, string caption, uint type);

    static void Fail(string msg)
    {
        MessageBoxW(IntPtr.Zero, msg, "Eden Updater", 0x10);
    }

    static string Step = "Start";

    // Eindeutige Suche: Name + exakte Parameterliste, nicht-generisch
    static MethodInfo Method(Type t, string name, bool isStatic, params Type[] pars)
    {
        BindingFlags f = BindingFlags.Public | (isStatic ? BindingFlags.Static : BindingFlags.Instance);
        foreach (MethodInfo m in t.GetMethods(f))
        {
            if (m.Name != name || m.IsGenericMethodDefinition) continue;
            ParameterInfo[] pi = m.GetParameters();
            if (pi.Length != pars.Length) continue;
            bool ok = true;
            for (int i = 0; i < pi.Length; i++) if (pi[i].ParameterType != pars[i]) { ok = false; break; }
            if (ok) return m;
        }
        throw new MissingMethodException(t.FullName, name);
    }

    // Eindeutige Suche: Name + Typ, beschreibbar, kein Indexer; abgeleitete Klasse zuerst
    static void SetProp(object target, string name, Type type, object value)
    {
        for (Type t = target.GetType(); t != null; t = t.BaseType)
        {
            foreach (PropertyInfo p in t.GetProperties(BindingFlags.Public | BindingFlags.Instance | BindingFlags.DeclaredOnly))
            {
                if (p.Name == name && p.PropertyType == type && p.CanWrite && p.GetIndexParameters().Length == 0)
                {
                    p.SetValue(target, value, null);
                    return;
                }
            }
        }
        throw new MissingMemberException(target.GetType().FullName, name);
    }

    // Millisekunden seit Prozessstart (nur fuer die Zeitmessung im automatischen Test)
    static string Since()
    {
        double ms = (DateTime.Now - System.Diagnostics.Process.GetCurrentProcess().StartTime).TotalMilliseconds;
        return ms.ToString("F0", System.Globalization.CultureInfo.InvariantCulture);
    }

    static string ReadScript()
    {
        Assembly me = Assembly.GetExecutingAssembly();
        using (Stream s = me.GetManifestResourceStream("EdenUpdater.ps1"))
        using (StreamReader r = new StreamReader(s, Encoding.UTF8, true))
        {
            return r.ReadToEnd();
        }
    }

    [STAThread]
    static int Main(string[] args)
    {
        try
        {
            string script = ReadScript();

            Assembly sma = Assembly.Load("System.Management.Automation, Version=3.0.0.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35");
            Type tFactory   = sma.GetType("System.Management.Automation.Runspaces.RunspaceFactory", true);
            Type tRunspace  = sma.GetType("System.Management.Automation.Runspaces.Runspace", true);
            Type tThreadOpt = sma.GetType("System.Management.Automation.Runspaces.PSThreadOptions", true);
            Type tPs        = sma.GetType("System.Management.Automation.PowerShell", true);

            Step = "CreateRunspace";
            object rs = Method(tFactory, "CreateRunspace", true).Invoke(null, null);
            Step = "ApartmentState";
            SetProp(rs, "ApartmentState", typeof(ApartmentState), ApartmentState.STA);
            Step = "ThreadOptions";
            SetProp(rs, "ThreadOptions", tThreadOpt, Enum.Parse(tThreadOpt, "UseCurrentThread"));
            Step = "Open";
            Method(rs.GetType(), "Open", false).Invoke(rs, null);

            bool perf = !string.IsNullOrEmpty(Environment.GetEnvironmentVariable("EDEN_UPDATER_SNAPSHOT_PERF"));
            if (perf) Environment.SetEnvironmentVariable("EDEN_UPDATER_T_OPEN", Since());

            Step = "PowerShell.Create";
            object ps = Method(tPs, "Create", true).Invoke(null, null);
            Step = "Runspace";
            SetProp(ps, "Runspace", tRunspace, rs);
            Step = "AddScript";
            Method(tPs, "AddScript", false, typeof(string)).Invoke(ps, new object[] { script });
            Step = "Skript";
            if (perf) Environment.SetEnvironmentVariable("EDEN_UPDATER_T_INVOKE", Since());
            try
            {
                Method(tPs, "Invoke", false).Invoke(ps, null);
            }
            finally
            {
                try { ((IDisposable)ps).Dispose(); } catch { }
                try { ((IDisposable)rs).Dispose(); } catch { }
            }
            return 0;
        }
        catch (TargetInvocationException ex)
        {
            Exception inner = ex.InnerException ?? ex;
            // "exit" im Skript ist kein Fehler
            if (inner.GetType().Name == "ExitException") return 0;
            Fail("Eden Updater konnte nicht gestartet werden:\n\n" + inner.Message + "\n\nSchritt: " + Step + " (" + inner.GetType().Name + ")");
            return 1;
        }
        catch (Exception ex)
        {
            Fail("Eden Updater konnte nicht gestartet werden:\n\n" + ex.Message + "\n\nSchritt: " + Step + " (" + ex.GetType().Name + ")");
            return 1;
        }
    }
}
