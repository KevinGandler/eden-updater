# ------------------------------------------------------------
#  Oberflaeche (XAML)
# ------------------------------------------------------------
$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Eden Updater" UseLayoutRounding="True" Width="1120" Height="790" MinWidth="960" MinHeight="680"
        WindowStartupLocation="CenterScreen" Background="{DynamicResource BrBg}"
        FontFamily="Segoe UI Variable Text, Segoe UI" FontSize="13" Foreground="{DynamicResource BrText}">
  <!-- Eigene Titelleiste: die oberen 36 px des Fensters sind der Ziehbereich -->
  <WindowChrome.WindowChrome>
    <WindowChrome CaptionHeight="36" ResizeBorderThickness="6" GlassFrameThickness="0,0,0,1" CornerRadius="0" UseAeroCaptionButtons="False"/>
  </WindowChrome.WindowChrome>
  <Window.Resources>
    <FontFamily x:Key="FontHead">Bahnschrift, Segoe UI Semibold</FontFamily>
    <FontFamily x:Key="FontIcon">Segoe Fluent Icons, Segoe MDL2 Assets</FontFamily>
    <FontFamily x:Key="FontMono">Cascadia Mono, Consolas</FontFamily>
    <SolidColorBrush x:Key="BrPanel"  Color="#171D26"/>
    <SolidColorBrush x:Key="BrPanel2" Color="#1E2632"/>
    <SolidColorBrush x:Key="BrCard"   Color="#E0171D26"/>
    <SolidColorBrush x:Key="BrLine"   Color="#2A3442"/>
    <SolidColorBrush x:Key="BrText"   Color="#E6EDF3"/>
    <SolidColorBrush x:Key="BrMuted"  Color="#8B98A9"/>
    <SolidColorBrush x:Key="BrAccent" Color="#22D3EE"/>
    <SolidColorBrush x:Key="BrAccent2" Color="#2288EE"/>
    <SolidColorBrush x:Key="BrAccentText" Color="#22D3EE"/>
    <SolidColorBrush x:Key="BrBg" Color="#0F1419"/>
    <SolidColorBrush x:Key="BrAccentFg" Color="#04222A"/>
    <SolidColorBrush x:Key="BrSel" Color="#12313A"/>
    <SolidColorBrush x:Key="BrSelStrong" Color="#164E5C"/>
    <SolidColorBrush x:Key="BrLog" Color="#0B0F14"/>
    <SolidColorBrush x:Key="BrBadgeNewBg" Color="#164E3F"/>
    <SolidColorBrush x:Key="BrBadgeNewFg" Color="#34D399"/>
    <SolidColorBrush x:Key="BrBadgeInstBg" Color="#0E3A47"/>
    <!-- Verlaeufe: werden beim Start per Code ersetzt und folgen dem Theme -->
    <LinearGradientBrush x:Key="GrAccent" StartPoint="0,0" EndPoint="1,1">
      <GradientStop Color="#22D3EE" Offset="0"/>
      <GradientStop Color="#2288EE" Offset="1"/>
    </LinearGradientBrush>
    <LinearGradientBrush x:Key="GrHero" StartPoint="0,0" EndPoint="1,0">
      <GradientStop Color="#3022D3EE" Offset="0"/>
      <GradientStop Color="#0022D3EE" Offset="1"/>
    </LinearGradientBrush>
    <RadialGradientBrush x:Key="GlowA">
      <GradientStop Color="#3822D3EE" Offset="0"/>
      <GradientStop Color="#0022D3EE" Offset="1"/>
    </RadialGradientBrush>
    <RadialGradientBrush x:Key="GlowB">
      <GradientStop Color="#262288EE" Offset="0"/>
      <GradientStop Color="#002288EE" Offset="1"/>
    </RadialGradientBrush>

    <Style TargetType="TextBlock">
      <Setter Property="Foreground" Value="{DynamicResource BrText}"/>
    </Style>

    <!-- Kleine Ueberschrift (Karten, Abschnitte) -->
    <Style x:Key="Label" TargetType="TextBlock">
      <Setter Property="FontFamily" Value="{StaticResource FontHead}"/>
      <Setter Property="FontSize" Value="10.5"/>
      <Setter Property="FontWeight" Value="Bold"/>
      <Setter Property="Foreground" Value="{DynamicResource BrMuted}"/>
    </Style>

    <!-- Feldbeschriftung in den Einstellungen -->
    <Style x:Key="FieldTitle" TargetType="TextBlock">
      <Setter Property="FontFamily" Value="{StaticResource FontHead}"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Foreground" Value="{DynamicResource BrText}"/>
      <Setter Property="TextWrapping" Value="Wrap"/>
    </Style>

    <Style x:Key="Hint" TargetType="TextBlock">
      <Setter Property="Foreground" Value="{DynamicResource BrMuted}"/>
      <Setter Property="FontSize" Value="12"/>
      <Setter Property="TextWrapping" Value="Wrap"/>
    </Style>

    <Style x:Key="Card" TargetType="Border">
      <Setter Property="Background" Value="{DynamicResource BrCard}"/>
      <Setter Property="BorderBrush" Value="{DynamicResource BrLine}"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="CornerRadius" Value="16"/>
      <Setter Property="Padding" Value="20"/>
    </Style>

    <!-- Hinweisleiste (z.B. "Eden laeuft gerade") -->
    <Style x:Key="Banner" TargetType="Border">
      <Setter Property="Background" Value="{DynamicResource BrBadgeInstBg}"/>
      <Setter Property="BorderBrush" Value="{DynamicResource BrSelStrong}"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="CornerRadius" Value="12"/>
      <Setter Property="Padding" Value="14,9"/>
    </Style>

    <!-- Rundes Icon-Feld als Abschnittskopf -->
    <Style x:Key="IconBadge" TargetType="Border">
      <Setter Property="Width" Value="34"/>
      <Setter Property="Height" Value="34"/>
      <Setter Property="CornerRadius" Value="10"/>
      <Setter Property="Background" Value="{DynamicResource BrSel}"/>
      <Setter Property="BorderBrush" Value="{DynamicResource BrSelStrong}"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="VerticalAlignment" Value="Center"/>
    </Style>
    <Style x:Key="IconBadgeGlyph" TargetType="TextBlock">
      <Setter Property="FontFamily" Value="{StaticResource FontIcon}"/>
      <Setter Property="FontSize" Value="15"/>
      <Setter Property="Foreground" Value="{DynamicResource BrAccentText}"/>
      <Setter Property="HorizontalAlignment" Value="Center"/>
      <Setter Property="VerticalAlignment" Value="Center"/>
    </Style>

    <Style TargetType="CheckBox">
      <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
      <Setter Property="Foreground" Value="{DynamicResource BrText}"/>
      <Setter Property="Margin" Value="0,6,0,6"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="CheckBox">
            <StackPanel x:Name="root" Orientation="Horizontal" Background="Transparent">
              <Grid Width="20" Height="20" VerticalAlignment="Center">
                <Border x:Name="box" Background="{DynamicResource BrPanel2}" BorderBrush="{DynamicResource BrLine}"
                        BorderThickness="1.5" CornerRadius="6"/>
                <Border x:Name="fill" Background="{DynamicResource GrAccent}" CornerRadius="6" Opacity="0"/>
                <Path x:Name="tick" Data="M 5 10.5 L 8.5 14 L 15 6.5" Stroke="{DynamicResource BrAccentFg}"
                      StrokeThickness="2.2" StrokeStartLineCap="Round" StrokeEndLineCap="Round"
                      StrokeLineJoin="Round" Opacity="0" RenderTransformOrigin="0.5,0.5">
                  <Path.RenderTransform>
                    <ScaleTransform x:Name="tsc" ScaleX="0.5" ScaleY="0.5"/>
                  </Path.RenderTransform>
                </Path>
                <Border x:Name="ring" BorderBrush="{DynamicResource BrAccent}" BorderThickness="1.5"
                        CornerRadius="6" Opacity="0"/>
              </Grid>
              <ContentPresenter Margin="12,0,0,0" VerticalAlignment="Center" RecognizesAccessKey="True"/>
            </StackPanel>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Trigger.EnterActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="ring" Storyboard.TargetProperty="Opacity" To="1" Duration="0:0:0.12"/></Storyboard></BeginStoryboard></Trigger.EnterActions>
                <Trigger.ExitActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="ring" Storyboard.TargetProperty="Opacity" To="0" Duration="0:0:0.18"/></Storyboard></BeginStoryboard></Trigger.ExitActions>
              </Trigger>
              <Trigger Property="IsChecked" Value="True">
                <Trigger.EnterActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="fill" Storyboard.TargetProperty="Opacity" To="1" Duration="0:0:0.15"/><DoubleAnimation Storyboard.TargetName="tick" Storyboard.TargetProperty="Opacity" To="1" Duration="0:0:0.12"/><DoubleAnimation Storyboard.TargetName="tsc" Storyboard.TargetProperty="ScaleX" To="1" Duration="0:0:0.22"><DoubleAnimation.EasingFunction><BackEase EasingMode="EaseOut" Amplitude="0.6"/></DoubleAnimation.EasingFunction></DoubleAnimation><DoubleAnimation Storyboard.TargetName="tsc" Storyboard.TargetProperty="ScaleY" To="1" Duration="0:0:0.22"><DoubleAnimation.EasingFunction><BackEase EasingMode="EaseOut" Amplitude="0.6"/></DoubleAnimation.EasingFunction></DoubleAnimation></Storyboard></BeginStoryboard></Trigger.EnterActions>
                <Trigger.ExitActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="fill" Storyboard.TargetProperty="Opacity" To="0" Duration="0:0:0.15"/><DoubleAnimation Storyboard.TargetName="tick" Storyboard.TargetProperty="Opacity" To="0" Duration="0:0:0.10"/><DoubleAnimation Storyboard.TargetName="tsc" Storyboard.TargetProperty="ScaleX" To="0.5" Duration="0:0:0.12"/><DoubleAnimation Storyboard.TargetName="tsc" Storyboard.TargetProperty="ScaleY" To="0.5" Duration="0:0:0.12"/></Storyboard></BeginStoryboard></Trigger.ExitActions>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter TargetName="root" Property="Opacity" Value="0.5"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- Ein/Aus-Schalter -->
    <Style x:Key="Switch" TargetType="CheckBox">
      <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="CheckBox">
            <Grid x:Name="root" Width="42" Height="24" Background="Transparent">
              <Border x:Name="track" CornerRadius="12" Background="{DynamicResource BrPanel2}" BorderBrush="{DynamicResource BrLine}" BorderThickness="1.5"/>
              <Border x:Name="fill" CornerRadius="12" Background="{DynamicResource GrAccent}" Opacity="0"/>
              <Ellipse x:Name="knob" Width="16" Height="16" HorizontalAlignment="Left" Margin="4,0,0,0" Fill="{DynamicResource BrMuted}" RenderTransformOrigin="0.5,0.5">
                <Ellipse.RenderTransform>
                  <TranslateTransform x:Name="kx" X="0"/>
                </Ellipse.RenderTransform>
              </Ellipse>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="IsChecked" Value="True">
                <Setter TargetName="knob" Property="Fill" Value="{DynamicResource BrAccentFg}"/>
                <Trigger.EnterActions><BeginStoryboard><Storyboard>
                  <DoubleAnimation Storyboard.TargetName="kx" Storyboard.TargetProperty="X" To="18" Duration="0:0:0.26"><DoubleAnimation.EasingFunction><BackEase EasingMode="EaseOut" Amplitude="0.5"/></DoubleAnimation.EasingFunction></DoubleAnimation>
                  <DoubleAnimation Storyboard.TargetName="fill" Storyboard.TargetProperty="Opacity" To="1" Duration="0:0:0.16"/>
                </Storyboard></BeginStoryboard></Trigger.EnterActions>
                <Trigger.ExitActions><BeginStoryboard><Storyboard>
                  <DoubleAnimation Storyboard.TargetName="kx" Storyboard.TargetProperty="X" To="0" Duration="0:0:0.22"><DoubleAnimation.EasingFunction><CubicEase EasingMode="EaseOut"/></DoubleAnimation.EasingFunction></DoubleAnimation>
                  <DoubleAnimation Storyboard.TargetName="fill" Storyboard.TargetProperty="Opacity" To="0" Duration="0:0:0.16"/>
                </Storyboard></BeginStoryboard></Trigger.ExitActions>
              </Trigger>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="track" Property="BorderBrush" Value="{DynamicResource BrAccent}"/>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter TargetName="root" Property="Opacity" Value="0.45"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- Einstellungszeile: Text links, Schalter rechts, ganze Zeile klickbar -->
    <Style x:Key="SwitchRow" TargetType="CheckBox">
      <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
      <Setter Property="Foreground" Value="{DynamicResource BrText}"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Margin" Value="-10,0,-10,2"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="CheckBox">
            <Grid x:Name="root" Background="Transparent">
              <Border x:Name="hov" Background="{DynamicResource BrPanel2}" CornerRadius="10" Opacity="0"/>
              <Grid Margin="10,9,10,9">
                <Grid.ColumnDefinitions>
                  <ColumnDefinition Width="*"/>
                  <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <ContentPresenter VerticalAlignment="Center" RecognizesAccessKey="True" Margin="0,0,14,0">
                  <ContentPresenter.Resources>
                    <Style TargetType="TextBlock">
                      <Setter Property="TextWrapping" Value="Wrap"/>
                      <Setter Property="Foreground" Value="{DynamicResource BrText}"/>
                    </Style>
                  </ContentPresenter.Resources>
                </ContentPresenter>
                <Grid Grid.Column="1" Width="42" Height="24" VerticalAlignment="Center">
                  <Border x:Name="track" CornerRadius="12" Background="{DynamicResource BrPanel2}" BorderBrush="{DynamicResource BrLine}" BorderThickness="1.5"/>
                  <Border x:Name="fill" CornerRadius="12" Background="{DynamicResource GrAccent}" Opacity="0"/>
                  <Ellipse x:Name="knob" Width="16" Height="16" HorizontalAlignment="Left" Margin="4,0,0,0" Fill="{DynamicResource BrMuted}">
                    <Ellipse.RenderTransform>
                      <TranslateTransform x:Name="kx" X="0"/>
                    </Ellipse.RenderTransform>
                  </Ellipse>
                </Grid>
              </Grid>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="IsChecked" Value="True">
                <Setter TargetName="knob" Property="Fill" Value="{DynamicResource BrAccentFg}"/>
                <Trigger.EnterActions><BeginStoryboard><Storyboard>
                  <DoubleAnimation Storyboard.TargetName="kx" Storyboard.TargetProperty="X" To="18" Duration="0:0:0.26"><DoubleAnimation.EasingFunction><BackEase EasingMode="EaseOut" Amplitude="0.5"/></DoubleAnimation.EasingFunction></DoubleAnimation>
                  <DoubleAnimation Storyboard.TargetName="fill" Storyboard.TargetProperty="Opacity" To="1" Duration="0:0:0.16"/>
                </Storyboard></BeginStoryboard></Trigger.EnterActions>
                <Trigger.ExitActions><BeginStoryboard><Storyboard>
                  <DoubleAnimation Storyboard.TargetName="kx" Storyboard.TargetProperty="X" To="0" Duration="0:0:0.22"><DoubleAnimation.EasingFunction><CubicEase EasingMode="EaseOut"/></DoubleAnimation.EasingFunction></DoubleAnimation>
                  <DoubleAnimation Storyboard.TargetName="fill" Storyboard.TargetProperty="Opacity" To="0" Duration="0:0:0.16"/>
                </Storyboard></BeginStoryboard></Trigger.ExitActions>
              </Trigger>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="track" Property="BorderBrush" Value="{DynamicResource BrAccent}"/>
                <Trigger.EnterActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="hov" Storyboard.TargetProperty="Opacity" To="1" Duration="0:0:0.12"/></Storyboard></BeginStoryboard></Trigger.EnterActions>
                <Trigger.ExitActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="hov" Storyboard.TargetProperty="Opacity" To="0" Duration="0:0:0.2"/></Storyboard></BeginStoryboard></Trigger.ExitActions>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter TargetName="root" Property="Opacity" Value="0.45"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style x:Key="ScrollThumb" TargetType="Thumb">
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Thumb">
            <Border x:Name="th" Background="{DynamicResource BrMuted}" CornerRadius="3" Margin="2" Opacity="0.35"/>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Trigger.EnterActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="th" Storyboard.TargetProperty="Opacity" To="0.85" Duration="0:0:0.15"/></Storyboard></BeginStoryboard></Trigger.EnterActions>
                <Trigger.ExitActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="th" Storyboard.TargetProperty="Opacity" To="0.35" Duration="0:0:0.25"/></Storyboard></BeginStoryboard></Trigger.ExitActions>
              </Trigger>
              <Trigger Property="IsDragging" Value="True">
                <Setter TargetName="th" Property="Background" Value="{DynamicResource BrAccent}"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style x:Key="PageBtn" TargetType="RepeatButton">
      <Setter Property="Focusable" Value="False"/>
      <Setter Property="IsTabStop" Value="False"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="RepeatButton">
            <Border Background="Transparent"/>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <ControlTemplate x:Key="VBar" TargetType="ScrollBar">
      <Grid Background="Transparent">
        <Track x:Name="PART_Track" IsDirectionReversed="True">
          <Track.DecreaseRepeatButton>
            <RepeatButton Command="ScrollBar.PageUpCommand" Style="{StaticResource PageBtn}"/>
          </Track.DecreaseRepeatButton>
          <Track.Thumb>
            <Thumb Style="{StaticResource ScrollThumb}"/>
          </Track.Thumb>
          <Track.IncreaseRepeatButton>
            <RepeatButton Command="ScrollBar.PageDownCommand" Style="{StaticResource PageBtn}"/>
          </Track.IncreaseRepeatButton>
        </Track>
      </Grid>
    </ControlTemplate>

    <ControlTemplate x:Key="HBar" TargetType="ScrollBar">
      <Grid Background="Transparent">
        <Track x:Name="PART_Track" IsDirectionReversed="False">
          <Track.DecreaseRepeatButton>
            <RepeatButton Command="ScrollBar.PageLeftCommand" Style="{StaticResource PageBtn}"/>
          </Track.DecreaseRepeatButton>
          <Track.Thumb>
            <Thumb Style="{StaticResource ScrollThumb}"/>
          </Track.Thumb>
          <Track.IncreaseRepeatButton>
            <RepeatButton Command="ScrollBar.PageRightCommand" Style="{StaticResource PageBtn}"/>
          </Track.IncreaseRepeatButton>
        </Track>
      </Grid>
    </ControlTemplate>

    <Style TargetType="ContextMenu">
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ContextMenu">
            <Border Background="{DynamicResource BrPanel2}" BorderBrush="{DynamicResource BrLine}"
                    BorderThickness="1" CornerRadius="10" Padding="4">
              <StackPanel IsItemsHost="True" KeyboardNavigation.DirectionalNavigation="Cycle"/>
            </Border>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style TargetType="MenuItem">
      <Setter Property="Foreground" Value="{DynamicResource BrText}"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="MenuItem">
            <Border x:Name="bd" Background="Transparent" CornerRadius="7" Padding="12,7" Margin="0,1">
              <ContentPresenter ContentSource="Header" RecognizesAccessKey="True"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsHighlighted" Value="True">
                <Setter TargetName="bd" Property="Background" Value="{DynamicResource BrSel}"/>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter TargetName="bd" Property="Opacity" Value="0.4"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style x:Key="{x:Static MenuItem.SeparatorStyleKey}" TargetType="Separator">
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Separator">
            <Border Height="1" Background="{DynamicResource BrLine}" Margin="8,4"/>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style TargetType="ToolTip">
      <Setter Property="Foreground" Value="{DynamicResource BrText}"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ToolTip">
            <Border Background="{DynamicResource BrPanel2}" BorderBrush="{DynamicResource BrLine}"
                    BorderThickness="1" CornerRadius="8" Padding="10,6">
              <ContentPresenter/>
            </Border>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style TargetType="ScrollBar">
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="Width" Value="10"/>
      <Setter Property="MinWidth" Value="10"/>
      <Setter Property="Template" Value="{StaticResource VBar}"/>
      <Style.Triggers>
        <Trigger Property="Orientation" Value="Horizontal">
          <Setter Property="Width" Value="Auto"/>
          <Setter Property="MinWidth" Value="0"/>
          <Setter Property="Height" Value="10"/>
          <Setter Property="MinHeight" Value="10"/>
          <Setter Property="Template" Value="{StaticResource HBar}"/>
        </Trigger>
      </Style.Triggers>
    </Style>

    <!-- Fortschritt: Verlauf in Akzentfarbe, beim Warten laeuft ein Lichtband durch -->
    <Style TargetType="ProgressBar">
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ProgressBar">
            <Grid x:Name="root" ClipToBounds="True">
              <Border x:Name="PART_Track" Background="{DynamicResource BrPanel2}" CornerRadius="2"/>
              <Border x:Name="PART_Indicator" HorizontalAlignment="Left" Background="{DynamicResource GrAccent}" CornerRadius="2"/>
              <Border x:Name="indet" Visibility="Collapsed" HorizontalAlignment="Left" Width="220" CornerRadius="2"
                      Background="{DynamicResource GrAccent}">
                <Border.OpacityMask>
                  <LinearGradientBrush StartPoint="0,0" EndPoint="1,0">
                    <GradientStop Color="#00000000" Offset="0"/>
                    <GradientStop Color="#FF000000" Offset="0.5"/>
                    <GradientStop Color="#00000000" Offset="1"/>
                  </LinearGradientBrush>
                </Border.OpacityMask>
                <Border.RenderTransform>
                  <TranslateTransform x:Name="itt" X="-230"/>
                </Border.RenderTransform>
              </Border>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="IsIndeterminate" Value="True">
                <Setter TargetName="PART_Indicator" Property="Visibility" Value="Collapsed"/>
                <Setter TargetName="indet" Property="Visibility" Value="Visible"/>
                <Trigger.EnterActions>
                  <BeginStoryboard x:Name="indetSb">
                    <Storyboard RepeatBehavior="Forever">
                      <DoubleAnimation Storyboard.TargetName="itt" Storyboard.TargetProperty="X" From="-230" To="1900" Duration="0:0:2.0"/>
                    </Storyboard>
                  </BeginStoryboard>
                </Trigger.EnterActions>
                <Trigger.ExitActions>
                  <StopStoryboard BeginStoryboardName="indetSb"/>
                </Trigger.ExitActions>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style TargetType="TextBox">
      <Setter Property="Background" Value="{DynamicResource BrPanel2}"/>
      <Setter Property="Foreground" Value="{DynamicResource BrText}"/>
      <Setter Property="CaretBrush" Value="{DynamicResource BrText}"/>
      <Setter Property="SelectionBrush" Value="{DynamicResource BrAccent}"/>
      <Setter Property="SelectionOpacity" Value="0.4"/>
      <Setter Property="BorderBrush" Value="{DynamicResource BrLine}"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Padding" Value="10,7"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="TextBox">
            <Grid>
              <Border x:Name="bd" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"
                      BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="10">
                <ScrollViewer x:Name="PART_ContentHost" Focusable="False" Padding="{TemplateBinding Padding}"
                              HorizontalScrollBarVisibility="{TemplateBinding HorizontalScrollBarVisibility}"
                              VerticalScrollBarVisibility="{TemplateBinding VerticalScrollBarVisibility}"/>
              </Border>
              <Border x:Name="focus" BorderBrush="{DynamicResource BrAccent}" BorderThickness="1.5" CornerRadius="10"
                      Opacity="0" IsHitTestVisible="False"/>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="IsKeyboardFocused" Value="True">
                <Trigger.EnterActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="focus" Storyboard.TargetProperty="Opacity" To="1" Duration="0:0:0.14"/></Storyboard></BeginStoryboard></Trigger.EnterActions>
                <Trigger.ExitActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="focus" Storyboard.TargetProperty="Opacity" To="0" Duration="0:0:0.2"/></Storyboard></BeginStoryboard></Trigger.ExitActions>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <ControlTemplate x:Key="CbToggle" TargetType="ToggleButton">
      <Border x:Name="bd" Background="{DynamicResource BrPanel2}" BorderBrush="{DynamicResource BrLine}" BorderThickness="1" CornerRadius="10">
        <Grid>
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="*"/>
            <ColumnDefinition Width="34"/>
          </Grid.ColumnDefinitions>
          <TextBlock x:Name="arrow" Grid.Column="1" Text="&#xE70D;" FontFamily="{StaticResource FontIcon}" FontSize="11"
                     Foreground="{DynamicResource BrMuted}" HorizontalAlignment="Center" VerticalAlignment="Center"
                     RenderTransformOrigin="0.5,0.5">
            <TextBlock.RenderTransform>
              <RotateTransform x:Name="arot" Angle="0"/>
            </TextBlock.RenderTransform>
          </TextBlock>
        </Grid>
      </Border>
      <ControlTemplate.Triggers>
        <Trigger Property="IsMouseOver" Value="True">
          <Setter TargetName="bd" Property="BorderBrush" Value="{DynamicResource BrMuted}"/>
        </Trigger>
        <Trigger Property="IsChecked" Value="True">
          <Setter TargetName="bd" Property="BorderBrush" Value="{DynamicResource BrAccent}"/>
          <Trigger.EnterActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="arot" Storyboard.TargetProperty="Angle" To="180" Duration="0:0:0.2"><DoubleAnimation.EasingFunction><CubicEase EasingMode="EaseOut"/></DoubleAnimation.EasingFunction></DoubleAnimation></Storyboard></BeginStoryboard></Trigger.EnterActions>
          <Trigger.ExitActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="arot" Storyboard.TargetProperty="Angle" To="0" Duration="0:0:0.2"><DoubleAnimation.EasingFunction><CubicEase EasingMode="EaseOut"/></DoubleAnimation.EasingFunction></DoubleAnimation></Storyboard></BeginStoryboard></Trigger.ExitActions>
        </Trigger>
      </ControlTemplate.Triggers>
    </ControlTemplate>

    <Style TargetType="ComboBoxItem">
      <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
      <Setter Property="Foreground" Value="{DynamicResource BrText}"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ComboBoxItem">
            <Border x:Name="bd" Background="Transparent" Padding="10,7" CornerRadius="7" Margin="4,1">
              <ContentPresenter/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsHighlighted" Value="True">
                <Setter TargetName="bd" Property="Background" Value="{DynamicResource BrSel}"/>
              </Trigger>
              <Trigger Property="IsSelected" Value="True">
                <Setter TargetName="bd" Property="Background" Value="{DynamicResource BrSelStrong}"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style TargetType="ComboBox">
      <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
      <Setter Property="Foreground" Value="{DynamicResource BrText}"/>
      <Setter Property="MinHeight" Value="36"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ComboBox">
            <Grid>
              <ToggleButton Template="{StaticResource CbToggle}" Focusable="False" ClickMode="Press"
                            IsChecked="{Binding IsDropDownOpen, Mode=TwoWay, RelativeSource={RelativeSource TemplatedParent}}"/>
              <ContentPresenter IsHitTestVisible="False"
                                Content="{TemplateBinding SelectionBoxItem}"
                                ContentTemplate="{TemplateBinding SelectionBoxItemTemplate}"
                                Margin="12,6,38,6" VerticalAlignment="Center" HorizontalAlignment="Left"/>
              <Popup Placement="Bottom" IsOpen="{TemplateBinding IsDropDownOpen}"
                     AllowsTransparency="True" Focusable="False" PopupAnimation="Slide">
                <Grid MinWidth="{TemplateBinding ActualWidth}" MaxHeight="{TemplateBinding MaxDropDownHeight}">
                  <Border Background="{DynamicResource BrPanel2}" BorderBrush="{DynamicResource BrLine}" BorderThickness="1"
                          CornerRadius="10" Margin="0,4,0,0" Padding="0,3">
                    <ScrollViewer>
                      <StackPanel IsItemsHost="True" KeyboardNavigation.DirectionalNavigation="Contained"/>
                    </ScrollViewer>
                  </Border>
                </Grid>
              </Popup>
            </Grid>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- Button: Icon kommt aus Tag (Segoe-Glyphe), Text aus Content -->
    <Style x:Key="Btn" TargetType="Button">
      <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
      <Setter Property="Foreground" Value="{DynamicResource BrText}"/>
      <Setter Property="Background" Value="{DynamicResource BrPanel2}"/>
      <Setter Property="BorderBrush" Value="{DynamicResource BrLine}"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Padding" Value="16,9"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Grid x:Name="root" RenderTransformOrigin="0.5,0.5">
              <Grid.RenderTransform>
                <ScaleTransform x:Name="sc" ScaleX="1" ScaleY="1"/>
              </Grid.RenderTransform>
              <Border x:Name="bd" Background="{TemplateBinding Background}"
                      BorderBrush="{TemplateBinding BorderBrush}"
                      BorderThickness="{TemplateBinding BorderThickness}"
                      CornerRadius="10" Padding="{TemplateBinding Padding}">
                <StackPanel Orientation="Horizontal" VerticalAlignment="Center"
                            HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}">
                  <TextBlock x:Name="ico" Text="{TemplateBinding Tag}" FontFamily="{StaticResource FontIcon}" FontSize="14"
                             Foreground="{TemplateBinding Foreground}" VerticalAlignment="Center" Margin="0,0,9,0"/>
                  <ContentPresenter VerticalAlignment="Center"/>
                </StackPanel>
              </Border>
              <Border x:Name="hl" Background="{DynamicResource BrText}" CornerRadius="10" Opacity="0" IsHitTestVisible="False"/>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="Tag" Value="{x:Null}">
                <Setter TargetName="ico" Property="Visibility" Value="Collapsed"/>
              </Trigger>
              <Trigger Property="IsMouseOver" Value="True">
                <Trigger.EnterActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="hl" Storyboard.TargetProperty="Opacity" To="0.09" Duration="0:0:0.15"/></Storyboard></BeginStoryboard></Trigger.EnterActions>
                <Trigger.ExitActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="hl" Storyboard.TargetProperty="Opacity" To="0" Duration="0:0:0.22"/></Storyboard></BeginStoryboard></Trigger.ExitActions>
              </Trigger>
              <Trigger Property="IsPressed" Value="True">
                <Trigger.EnterActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="sc" Storyboard.TargetProperty="ScaleX" To="0.96" Duration="0:0:0.08"/><DoubleAnimation Storyboard.TargetName="sc" Storyboard.TargetProperty="ScaleY" To="0.96" Duration="0:0:0.08"/></Storyboard></BeginStoryboard></Trigger.EnterActions>
                <Trigger.ExitActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="sc" Storyboard.TargetProperty="ScaleX" To="1" Duration="0:0:0.3"><DoubleAnimation.EasingFunction><BackEase EasingMode="EaseOut" Amplitude="0.9"/></DoubleAnimation.EasingFunction></DoubleAnimation><DoubleAnimation Storyboard.TargetName="sc" Storyboard.TargetProperty="ScaleY" To="1" Duration="0:0:0.3"><DoubleAnimation.EasingFunction><BackEase EasingMode="EaseOut" Amplitude="0.9"/></DoubleAnimation.EasingFunction></DoubleAnimation></Storyboard></BeginStoryboard></Trigger.ExitActions>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter TargetName="root" Property="Opacity" Value="0.4"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- Hauptaktion: Akzent-Verlauf mit weichem Leuchten darunter -->
    <Style x:Key="BtnPrimary" TargetType="Button">
      <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
      <Setter Property="Foreground" Value="{DynamicResource BrAccentFg}"/>
      <Setter Property="Background" Value="{DynamicResource GrAccent}"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Padding" Value="16,9"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Grid x:Name="root" RenderTransformOrigin="0.5,0.5">
              <Grid.RenderTransform>
                <ScaleTransform x:Name="sc" ScaleX="1" ScaleY="1"/>
              </Grid.RenderTransform>
              <Border x:Name="glow" Background="{TemplateBinding Background}" CornerRadius="10" Margin="8,10,8,-3"
                      Opacity="0.30" IsHitTestVisible="False">
                <Border.Effect>
                  <BlurEffect Radius="14" KernelType="Gaussian"/>
                </Border.Effect>
              </Border>
              <Border x:Name="bd" Background="{TemplateBinding Background}" CornerRadius="10" Padding="{TemplateBinding Padding}">
                <StackPanel Orientation="Horizontal" VerticalAlignment="Center"
                            HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}">
                  <TextBlock x:Name="ico" Text="{TemplateBinding Tag}" FontFamily="{StaticResource FontIcon}" FontSize="14"
                             Foreground="{TemplateBinding Foreground}" VerticalAlignment="Center" Margin="0,0,9,0"/>
                  <ContentPresenter VerticalAlignment="Center" TextElement.Foreground="{TemplateBinding Foreground}"/>
                </StackPanel>
              </Border>
              <Border x:Name="hl" Background="White" CornerRadius="10" Opacity="0" IsHitTestVisible="False"/>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="Tag" Value="{x:Null}">
                <Setter TargetName="ico" Property="Visibility" Value="Collapsed"/>
              </Trigger>
              <Trigger Property="IsMouseOver" Value="True">
                <Trigger.EnterActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="hl" Storyboard.TargetProperty="Opacity" To="0.14" Duration="0:0:0.15"/><DoubleAnimation Storyboard.TargetName="glow" Storyboard.TargetProperty="Opacity" To="0.75" Duration="0:0:0.2"/></Storyboard></BeginStoryboard></Trigger.EnterActions>
                <Trigger.ExitActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="hl" Storyboard.TargetProperty="Opacity" To="0" Duration="0:0:0.25"/><DoubleAnimation Storyboard.TargetName="glow" Storyboard.TargetProperty="Opacity" To="0.30" Duration="0:0:0.3"/></Storyboard></BeginStoryboard></Trigger.ExitActions>
              </Trigger>
              <Trigger Property="IsPressed" Value="True">
                <Trigger.EnterActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="sc" Storyboard.TargetProperty="ScaleX" To="0.96" Duration="0:0:0.08"/><DoubleAnimation Storyboard.TargetName="sc" Storyboard.TargetProperty="ScaleY" To="0.96" Duration="0:0:0.08"/></Storyboard></BeginStoryboard></Trigger.EnterActions>
                <Trigger.ExitActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="sc" Storyboard.TargetProperty="ScaleX" To="1" Duration="0:0:0.3"><DoubleAnimation.EasingFunction><BackEase EasingMode="EaseOut" Amplitude="0.9"/></DoubleAnimation.EasingFunction></DoubleAnimation><DoubleAnimation Storyboard.TargetName="sc" Storyboard.TargetProperty="ScaleY" To="1" Duration="0:0:0.3"><DoubleAnimation.EasingFunction><BackEase EasingMode="EaseOut" Amplitude="0.9"/></DoubleAnimation.EasingFunction></DoubleAnimation></Storyboard></BeginStoryboard></Trigger.ExitActions>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter TargetName="root" Property="Opacity" Value="0.4"/>
                <Setter TargetName="glow" Property="Visibility" Value="Collapsed"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style x:Key="BtnGhost" TargetType="Button" BasedOn="{StaticResource Btn}">
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="Foreground" Value="{DynamicResource BrMuted}"/>
      <Setter Property="Padding" Value="10,6"/>
    </Style>

    <!-- Fensterknoepfe (Minimieren, Maximieren, Schliessen); Schliessen wird ueber Uid="close" rot -->
    <Style x:Key="BtnCaption" TargetType="Button">
      <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
      <Setter Property="Focusable" Value="False"/>
      <Setter Property="Width" Value="46"/>
      <Setter Property="Height" Value="34"/>
      <Setter Property="Foreground" Value="{DynamicResource BrText}"/>
      <Setter Property="WindowChrome.IsHitTestVisibleInChrome" Value="True"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Grid Background="Transparent">
              <Border x:Name="hl" Background="{DynamicResource BrText}" Opacity="0"/>
              <Border x:Name="red" Background="#E81123" Opacity="0"/>
              <TextBlock x:Name="ico" Text="{TemplateBinding Tag}" FontFamily="{StaticResource FontIcon}" FontSize="10"
                         Foreground="{TemplateBinding Foreground}" HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Trigger.EnterActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="hl" Storyboard.TargetProperty="Opacity" To="0.10" Duration="0:0:0.10"/></Storyboard></BeginStoryboard></Trigger.EnterActions>
                <Trigger.ExitActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="hl" Storyboard.TargetProperty="Opacity" To="0" Duration="0:0:0.18"/></Storyboard></BeginStoryboard></Trigger.ExitActions>
              </Trigger>
              <Trigger Property="IsPressed" Value="True">
                <Setter TargetName="ico" Property="Opacity" Value="0.6"/>
              </Trigger>
              <MultiTrigger>
                <MultiTrigger.Conditions>
                  <Condition Property="Uid" Value="close"/>
                  <Condition Property="IsMouseOver" Value="True"/>
                </MultiTrigger.Conditions>
                <Setter TargetName="red" Property="Opacity" Value="1"/>
                <Setter TargetName="ico" Property="Foreground" Value="White"/>
              </MultiTrigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- Getoente Variante (z.B. "Eden starten") -->
    <Style x:Key="BtnTonal" TargetType="Button" BasedOn="{StaticResource Btn}">
      <Setter Property="Background" Value="{DynamicResource BrSel}"/>
      <Setter Property="BorderBrush" Value="{DynamicResource BrSelStrong}"/>
      <Setter Property="Foreground" Value="{DynamicResource BrAccentText}"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
    </Style>

    <!-- Seitenleiste: der aktive Eintrag bekommt per Code helle Schrift und ein Akzent-Icon (BorderBrush);
         den Hintergrund liefert die gleitende Markierung (NavPill) -->
    <Style x:Key="BtnNav" TargetType="Button">
      <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
      <Setter Property="Foreground" Value="{DynamicResource BrMuted}"/>
      <Setter Property="BorderBrush" Value="{DynamicResource BrMuted}"/>
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="Height" Value="40"/>
      <Setter Property="Margin" Value="0,0,0,2"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Grid Background="Transparent">
              <Border x:Name="hl" Background="{DynamicResource BrText}" CornerRadius="11" Opacity="0" IsHitTestVisible="False"/>
              <StackPanel Orientation="Horizontal" Margin="16,0,10,0" VerticalAlignment="Center">
                <TextBlock x:Name="ico" Text="{TemplateBinding Tag}" FontFamily="{StaticResource FontIcon}" FontSize="16"
                           Foreground="{TemplateBinding BorderBrush}" VerticalAlignment="Center" Margin="0,0,13,0"
                           RenderTransformOrigin="0.5,0.5">
                  <TextBlock.RenderTransform>
                    <ScaleTransform x:Name="isc" ScaleX="1" ScaleY="1"/>
                  </TextBlock.RenderTransform>
                </TextBlock>
                <ContentPresenter VerticalAlignment="Center" TextElement.Foreground="{TemplateBinding Foreground}"/>
              </StackPanel>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Trigger.EnterActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="hl" Storyboard.TargetProperty="Opacity" To="0.05" Duration="0:0:0.15"/><DoubleAnimation Storyboard.TargetName="isc" Storyboard.TargetProperty="ScaleX" To="1.14" Duration="0:0:0.2"><DoubleAnimation.EasingFunction><BackEase EasingMode="EaseOut" Amplitude="0.8"/></DoubleAnimation.EasingFunction></DoubleAnimation><DoubleAnimation Storyboard.TargetName="isc" Storyboard.TargetProperty="ScaleY" To="1.14" Duration="0:0:0.2"><DoubleAnimation.EasingFunction><BackEase EasingMode="EaseOut" Amplitude="0.8"/></DoubleAnimation.EasingFunction></DoubleAnimation></Storyboard></BeginStoryboard></Trigger.EnterActions>
                <Trigger.ExitActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="hl" Storyboard.TargetProperty="Opacity" To="0" Duration="0:0:0.22"/><DoubleAnimation Storyboard.TargetName="isc" Storyboard.TargetProperty="ScaleX" To="1" Duration="0:0:0.2"/><DoubleAnimation Storyboard.TargetName="isc" Storyboard.TargetProperty="ScaleY" To="1" Duration="0:0:0.2"/></Storyboard></BeginStoryboard></Trigger.ExitActions>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- Listeneintrag mit Auswahl -->
    <Style x:Key="LbItem" TargetType="ListBoxItem">
      <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
      <Setter Property="Foreground" Value="{DynamicResource BrText}"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Padding" Value="12,9,12,9"/>
      <Setter Property="Margin" Value="0,0,0,2"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ListBoxItem">
            <Grid x:Name="root">
              <Grid.RenderTransform>
                <TranslateTransform x:Name="tt" Y="0"/>
              </Grid.RenderTransform>
              <Border x:Name="hov" Background="{DynamicResource BrPanel2}" CornerRadius="11" Opacity="0"/>
              <Border x:Name="selb" Background="{DynamicResource BrSel}" BorderBrush="{DynamicResource BrSelStrong}" BorderThickness="1"
                      CornerRadius="11" Opacity="0"/>
              <ContentPresenter Margin="{TemplateBinding Padding}"/>
            </Grid>
            <ControlTemplate.Triggers>
              <EventTrigger RoutedEvent="FrameworkElement.Loaded"><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="root" Storyboard.TargetProperty="Opacity" From="0" To="1" Duration="0:0:0.30"/><DoubleAnimation Storyboard.TargetName="tt" Storyboard.TargetProperty="Y" From="10" To="0" Duration="0:0:0.30"><DoubleAnimation.EasingFunction><CubicEase EasingMode="EaseOut"/></DoubleAnimation.EasingFunction></DoubleAnimation></Storyboard></BeginStoryboard></EventTrigger>
              <Trigger Property="IsMouseOver" Value="True">
                <Trigger.EnterActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="hov" Storyboard.TargetProperty="Opacity" To="1" Duration="0:0:0.12"/></Storyboard></BeginStoryboard></Trigger.EnterActions>
                <Trigger.ExitActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="hov" Storyboard.TargetProperty="Opacity" To="0" Duration="0:0:0.2"/></Storyboard></BeginStoryboard></Trigger.ExitActions>
              </Trigger>
              <Trigger Property="IsSelected" Value="True">
                <Trigger.EnterActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="selb" Storyboard.TargetProperty="Opacity" To="1" Duration="0:0:0.18"/></Storyboard></BeginStoryboard></Trigger.EnterActions>
                <Trigger.ExitActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="selb" Storyboard.TargetProperty="Opacity" To="0" Duration="0:0:0.18"/></Storyboard></BeginStoryboard></Trigger.ExitActions>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- Versionsliste: Eintraege liegen ohne Abstand aneinander, damit die Zeitleiste durchlaeuft -->
    <Style x:Key="LbItemLine" TargetType="ListBoxItem" BasedOn="{StaticResource LbItem}">
      <Setter Property="Padding" Value="8,0,12,0"/>
      <Setter Property="Margin" Value="0"/>
    </Style>

    <!-- Zeile ohne Auswahl (Mods, Inhalte, Backups): nur Hover -->
    <Style x:Key="LbRow" TargetType="ListBoxItem">
      <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
      <Setter Property="Foreground" Value="{DynamicResource BrText}"/>
      <Setter Property="Padding" Value="14,10,8,10"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ListBoxItem">
            <Grid x:Name="root" Margin="0,0,0,2">
              <Grid.RenderTransform>
                <TranslateTransform x:Name="tt" Y="0"/>
              </Grid.RenderTransform>
              <Border x:Name="hov" Background="{DynamicResource BrPanel2}" CornerRadius="11" Opacity="0"/>
              <ContentPresenter Margin="{TemplateBinding Padding}"/>
            </Grid>
            <ControlTemplate.Triggers>
              <EventTrigger RoutedEvent="FrameworkElement.Loaded"><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="root" Storyboard.TargetProperty="Opacity" From="0" To="1" Duration="0:0:0.28"/><DoubleAnimation Storyboard.TargetName="tt" Storyboard.TargetProperty="Y" From="8" To="0" Duration="0:0:0.28"><DoubleAnimation.EasingFunction><CubicEase EasingMode="EaseOut"/></DoubleAnimation.EasingFunction></DoubleAnimation></Storyboard></BeginStoryboard></EventTrigger>
              <Trigger Property="IsMouseOver" Value="True">
                <Trigger.EnterActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="hov" Storyboard.TargetProperty="Opacity" To="1" Duration="0:0:0.12"/></Storyboard></BeginStoryboard></Trigger.EnterActions>
                <Trigger.ExitActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="hov" Storyboard.TargetProperty="Opacity" To="0" Duration="0:0:0.2"/></Storyboard></BeginStoryboard></Trigger.ExitActions>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- Spiele-Kachel: hebt sich beim Ueberfahren an, Auswahl = Akzentrahmen -->
    <Style x:Key="GameTile" TargetType="ListBoxItem">
      <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
      <Setter Property="Foreground" Value="{DynamicResource BrText}"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Width" Value="150"/>
      <Setter Property="Margin" Value="0,0,12,12"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ListBoxItem">
            <Grid x:Name="root" RenderTransformOrigin="0.5,0.5">
              <Grid.RenderTransform>
                <ScaleTransform x:Name="sc" ScaleX="1" ScaleY="1"/>
              </Grid.RenderTransform>
              <Border x:Name="bg" Background="{DynamicResource BrCard}" BorderBrush="{DynamicResource BrLine}" BorderThickness="1" CornerRadius="16"/>
              <Border x:Name="hov" Background="{DynamicResource BrPanel2}" CornerRadius="16" Opacity="0"/>
              <Border x:Name="ring" BorderBrush="{DynamicResource BrAccent}" BorderThickness="2" CornerRadius="16" Opacity="0"/>
              <ContentPresenter Margin="9"/>
            </Grid>
            <ControlTemplate.Triggers>
              <EventTrigger RoutedEvent="FrameworkElement.Loaded"><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="root" Storyboard.TargetProperty="Opacity" From="0" To="1" Duration="0:0:0.30"/><DoubleAnimation Storyboard.TargetName="sc" Storyboard.TargetProperty="ScaleX" From="0.94" To="1" Duration="0:0:0.32"><DoubleAnimation.EasingFunction><CubicEase EasingMode="EaseOut"/></DoubleAnimation.EasingFunction></DoubleAnimation><DoubleAnimation Storyboard.TargetName="sc" Storyboard.TargetProperty="ScaleY" From="0.94" To="1" Duration="0:0:0.32"><DoubleAnimation.EasingFunction><CubicEase EasingMode="EaseOut"/></DoubleAnimation.EasingFunction></DoubleAnimation></Storyboard></BeginStoryboard></EventTrigger>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter Property="Panel.ZIndex" Value="2"/>
                <Trigger.EnterActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="hov" Storyboard.TargetProperty="Opacity" To="1" Duration="0:0:0.12"/><DoubleAnimation Storyboard.TargetName="sc" Storyboard.TargetProperty="ScaleX" To="1.045" Duration="0:0:0.24"><DoubleAnimation.EasingFunction><BackEase EasingMode="EaseOut" Amplitude="0.7"/></DoubleAnimation.EasingFunction></DoubleAnimation><DoubleAnimation Storyboard.TargetName="sc" Storyboard.TargetProperty="ScaleY" To="1.045" Duration="0:0:0.24"><DoubleAnimation.EasingFunction><BackEase EasingMode="EaseOut" Amplitude="0.7"/></DoubleAnimation.EasingFunction></DoubleAnimation></Storyboard></BeginStoryboard></Trigger.EnterActions>
                <Trigger.ExitActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="hov" Storyboard.TargetProperty="Opacity" To="0" Duration="0:0:0.2"/><DoubleAnimation Storyboard.TargetName="sc" Storyboard.TargetProperty="ScaleX" To="1" Duration="0:0:0.2"/><DoubleAnimation Storyboard.TargetName="sc" Storyboard.TargetProperty="ScaleY" To="1" Duration="0:0:0.2"/></Storyboard></BeginStoryboard></Trigger.ExitActions>
              </Trigger>
              <Trigger Property="IsSelected" Value="True">
                <Trigger.EnterActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="ring" Storyboard.TargetProperty="Opacity" To="1" Duration="0:0:0.16"/></Storyboard></BeginStoryboard></Trigger.EnterActions>
                <Trigger.ExitActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="ring" Storyboard.TargetProperty="Opacity" To="0" Duration="0:0:0.16"/></Storyboard></BeginStoryboard></Trigger.ExitActions>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- Spiel in den Seitenlisten (Mods, Updates/DLC, Spieldaten) -->
    <DataTemplate x:Key="GameRow">
      <Grid>
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="Auto"/>
          <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>
        <Grid Width="38" Height="38" VerticalAlignment="Center">
          <Border CornerRadius="10" Background="{DynamicResource BrSelStrong}"/>
          <Border CornerRadius="10" Background="{Binding TileBrush}">
            <TextBlock Text="{Binding Initial}" FontFamily="{StaticResource FontHead}" FontSize="16" FontWeight="Bold"
                       Foreground="#F5FFFFFF" HorizontalAlignment="Center" VerticalAlignment="Center"/>
          </Border>
          <Border CornerRadius="10">
            <Border.Background>
              <ImageBrush ImageSource="{Binding IconImg}" Stretch="UniformToFill"/>
            </Border.Background>
          </Border>
        </Grid>
        <StackPanel Grid.Column="1" Margin="12,0,0,0" VerticalAlignment="Center">
          <TextBlock Text="{Binding Name}" Foreground="{DynamicResource BrText}" FontFamily="{StaticResource FontHead}" FontSize="13.5"
                     FontWeight="SemiBold" TextWrapping="Wrap" LineHeight="17"/>
          <TextBlock Text="{Binding Info}" Foreground="{DynamicResource BrMuted}" FontSize="11.5" Margin="0,2,0,0" TextTrimming="CharacterEllipsis"/>
        </StackPanel>
      </Grid>
    </DataTemplate>
  </Window.Resources>

  <Grid x:Name="RootGrid" Background="{DynamicResource BrBg}">
    <Grid.ColumnDefinitions>
      <ColumnDefinition Width="238"/>
      <ColumnDefinition Width="*"/>
    </Grid.ColumnDefinitions>

    <!-- Weiches Leuchten in den Theme-Farben hinter der Oberflaeche -->
    <Canvas Grid.ColumnSpan="2" IsHitTestVisible="False" ClipToBounds="True">
      <Ellipse Width="760" Height="760" Canvas.Left="-300" Canvas.Top="-380" Fill="{DynamicResource GlowA}"/>
      <Ellipse Width="900" Height="900" Canvas.Right="-360" Canvas.Bottom="-520" Fill="{DynamicResource GlowB}"/>
    </Canvas>

    <!-- ============ Seitenleiste ============ -->
    <Grid x:Name="SideBar" Grid.Column="0" Margin="14,18,6,18">
      <Grid.RenderTransform>
        <TranslateTransform/>
      </Grid.RenderTransform>
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="*"/>
        <RowDefinition Height="Auto"/>
      </Grid.RowDefinitions>

      <StackPanel Orientation="Horizontal" Margin="10,2,0,0">
        <Grid Width="44" Height="44">
          <Border CornerRadius="13" Background="{DynamicResource GrAccent}" Margin="5,8,5,-2" Opacity="0.55" IsHitTestVisible="False">
            <Border.Effect>
              <BlurEffect Radius="14" KernelType="Gaussian"/>
            </Border.Effect>
          </Border>
          <Border CornerRadius="13" Background="{DynamicResource GrAccent}">
            <Viewbox>
              <Canvas Width="64" Height="64">
                <!-- Kreispfeil: dreht sich, solange etwas laeuft -->
                <Canvas x:Name="LogoRing" Width="64" Height="64" RenderTransformOrigin="0.5,0.5">
                  <Canvas.RenderTransform>
                    <RotateTransform Angle="0"/>
                  </Canvas.RenderTransform>
                  <Path Data="M 42.61,19.36 A 16.5,16.5 0 1 1 19.36,21.39" Stroke="{DynamicResource BrAccentFg}" StrokeThickness="5"
                        StrokeStartLineCap="Round" StrokeEndLineCap="Round"/>
                  <Path Data="M 24.5,15.26 L 14.76,17.53 L 23.96,25.25 Z" Fill="{DynamicResource BrAccentFg}"/>
                </Canvas>
                <Path Data="M 32,23 L 32,39 M 25.5,33.5 L 32,40 L 38.5,33.5" Stroke="{DynamicResource BrAccentFg}" StrokeThickness="5"
                      StrokeStartLineCap="Round" StrokeEndLineCap="Round" StrokeLineJoin="Round"/>
              </Canvas>
            </Viewbox>
          </Border>
        </Grid>
        <StackPanel Margin="13,0,0,0" VerticalAlignment="Center">
          <TextBlock Text="EDEN" FontFamily="{StaticResource FontHead}" FontSize="19" FontWeight="Bold"/>
          <TextBlock Text="UPDATER" FontFamily="{StaticResource FontHead}" FontSize="10.5" FontWeight="Bold"
                     Foreground="{DynamicResource BrAccentText}" Margin="1,-2,0,0"/>
        </StackPanel>
      </StackPanel>

      <Grid x:Name="NavHost" Grid.Row="1" Margin="0,28,0,0">
        <!-- Gleitende Markierung des aktiven Eintrags -->
        <Border x:Name="NavPill" Height="40" VerticalAlignment="Top" CornerRadius="11" Opacity="0"
                Background="{DynamicResource BrSel}" BorderBrush="{DynamicResource BrSelStrong}" BorderThickness="1">
          <Border.RenderTransform>
            <TranslateTransform Y="0"/>
          </Border.RenderTransform>
          <Border Width="3" Height="18" HorizontalAlignment="Left" Margin="-1,0,0,0" CornerRadius="2"
                  Background="{DynamicResource GrAccent}"/>
        </Border>
        <StackPanel>
          <Button x:Name="BtnNavVer"   Tag="&#xE8FD;" Content="{DynamicResource L_NavVersions}" Style="{StaticResource BtnNav}"/>
          <Button x:Name="BtnNavNotes" Tag="&#xE8A5;" Content="{DynamicResource L_NavNotes}"    Style="{StaticResource BtnNav}"/>
          <Border Height="1" Background="{DynamicResource BrLine}" Margin="16,9,16,10"/>
          <Button x:Name="BtnNavGames" Tag="&#xE7FC;" Content="{DynamicResource L_NavGames}"    Style="{StaticResource BtnNav}"/>
          <Button x:Name="BtnNavMods"  Tag="&#xEA86;" Content="{DynamicResource L_NavMods}"     Style="{StaticResource BtnNav}"/>
          <Button x:Name="BtnNavContent" Tag="&#xE7B8;" Content="{DynamicResource L_NavContent}" Style="{StaticResource BtnNav}"/>
          <Button x:Name="BtnNavSaves" Tag="&#xE74E;" Content="{DynamicResource L_NavSaves}"    Style="{StaticResource BtnNav}"/>
          <Border Height="1" Background="{DynamicResource BrLine}" Margin="16,9,16,10"/>
          <Button x:Name="BtnNavFw"    Tag="&#xE950;" Content="{DynamicResource L_NavFirmware}" Style="{StaticResource BtnNav}"/>
          <Button x:Name="BtnNavSet"   Tag="&#xE713;" Content="{DynamicResource L_NavSettings}" Style="{StaticResource BtnNav}"/>
        </StackPanel>
      </Grid>

      <!-- Installierte Version + Eden starten -->
      <Border Grid.Row="3" Style="{StaticResource Card}" Padding="14,12,14,14" Margin="0,0,8,0">
        <StackPanel>
          <TextBlock Style="{StaticResource Label}" Text="{DynamicResource L_CardInstalled}"/>
          <TextBlock x:Name="TxtSideVer" FontFamily="{StaticResource FontHead}" FontSize="13.5" FontWeight="SemiBold"
                     TextTrimming="CharacterEllipsis" Margin="0,3,0,0"
                     ToolTip="{Binding Text, RelativeSource={RelativeSource Self}}"/>
          <Button x:Name="BtnLaunch" Tag="&#xE768;" Content="{DynamicResource L_BtnLaunch}"
                  Style="{StaticResource BtnTonal}" HorizontalContentAlignment="Center" Padding="12,10" Margin="0,12,0,0"/>
        </StackPanel>
      </Border>
    </Grid>

    <!-- ============ Hauptbereich ============ -->
    <Grid x:Name="MainArea" Grid.Column="1" Margin="14,38,26,18">
      <Grid.RenderTransform>
        <TranslateTransform/>
      </Grid.RenderTransform>
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="*"/>
        <RowDefinition Height="Auto"/>
      </Grid.RowDefinitions>

      <!-- Seitentitel -->
      <Grid Grid.Row="0">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="Auto"/>
        </Grid.ColumnDefinitions>
        <StackPanel x:Name="HeadText" Grid.Column="0">
          <StackPanel.RenderTransform>
            <TranslateTransform/>
          </StackPanel.RenderTransform>
          <TextBlock x:Name="TxtPageTitle" FontFamily="{StaticResource FontHead}" FontSize="30" FontWeight="SemiBold"/>
          <TextBlock x:Name="TxtPageSub" Text="{DynamicResource L_AppSubtitle}" Foreground="{DynamicResource BrMuted}" Margin="1,2,0,0"
                     TextTrimming="CharacterEllipsis"/>
        </StackPanel>
        <!-- Update-Status oben rechts (Klick fuehrt zu den Versionen) -->
        <Border x:Name="ChipState" Grid.Column="1" CornerRadius="17" Padding="14,8" Margin="16,6,0,0"
                VerticalAlignment="Top" Visibility="Collapsed" BorderThickness="1" Cursor="Hand"
                Background="{DynamicResource BrBadgeNewBg}" BorderBrush="{DynamicResource BrLine}">
          <StackPanel Orientation="Horizontal">
            <Grid Width="10" Height="10" VerticalAlignment="Center">
              <Ellipse x:Name="DotRing" Fill="{Binding Fill, ElementName=DotState}" Opacity="0" RenderTransformOrigin="0.5,0.5">
                <Ellipse.RenderTransform>
                  <ScaleTransform ScaleX="1" ScaleY="1"/>
                </Ellipse.RenderTransform>
              </Ellipse>
              <Ellipse x:Name="DotState" Width="8" Height="8" Fill="{DynamicResource BrBadgeNewFg}"/>
            </Grid>
            <TextBlock x:Name="TxtChip" FontFamily="{StaticResource FontHead}" FontSize="12.5" FontWeight="Bold"
                       Margin="9,0,0,0" VerticalAlignment="Center" Foreground="{DynamicResource BrBadgeNewFg}"/>
          </StackPanel>
        </Border>
      </Grid>

      <!-- Inhalt -->
      <Grid Grid.Row="1" Margin="0,18,0,0">
        <!-- Seite: Versionen -->
        <Grid x:Name="PanelVersions">
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
          </Grid.RowDefinitions>
          <Grid.ColumnDefinitions>
            <ColumnDefinition x:Name="ColList" Width="*"/>
            <ColumnDefinition x:Name="ColNotes" Width="0"/>
          </Grid.ColumnDefinitions>
          <Grid.RenderTransform>
            <TranslateTransform/>
          </Grid.RenderTransform>

          <!-- Installiert -> Neueste -->
          <Border Grid.Row="0" Grid.ColumnSpan="2" CornerRadius="18" BorderThickness="1" Margin="0,0,0,14"
                  Background="{DynamicResource BrCard}" BorderBrush="{DynamicResource BrLine}">
            <Grid>
              <Border CornerRadius="17" Background="{DynamicResource GrHero}"/>
              <Grid Margin="24,18,20,18">
                <Grid.ColumnDefinitions>
                  <ColumnDefinition Width="*" MinWidth="90"/>
                  <ColumnDefinition Width="Auto"/>
                  <ColumnDefinition Width="*" MinWidth="90"/>
                  <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <StackPanel Grid.Column="0" VerticalAlignment="Center">
                  <TextBlock Style="{StaticResource Label}" Text="{DynamicResource L_CardInstalled}"/>
                  <TextBlock x:Name="TxtInstalled" ToolTip="{Binding Text, RelativeSource={RelativeSource Self}}" FontFamily="{StaticResource FontHead}" FontSize="21" FontWeight="SemiBold"
                             TextTrimming="CharacterEllipsis" Margin="0,5,0,0"/>
                </StackPanel>
                <!-- Pfeile laufen von links nach rechts, wenn ein Update wartet -->
                <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center" Margin="18,16,20,0">
                  <TextBlock x:Name="Flow1" Text="&#xE76C;" FontFamily="{StaticResource FontIcon}" FontSize="12" Opacity="0.25" Foreground="{DynamicResource BrAccentText}"/>
                  <TextBlock x:Name="Flow2" Text="&#xE76C;" FontFamily="{StaticResource FontIcon}" FontSize="12" Opacity="0.5" Margin="-2,0,0,0" Foreground="{DynamicResource BrAccentText}"/>
                  <TextBlock x:Name="Flow3" Text="&#xE76C;" FontFamily="{StaticResource FontIcon}" FontSize="12" Opacity="0.9" Margin="-2,0,0,0" Foreground="{DynamicResource BrAccentText}"/>
                </StackPanel>
                <StackPanel Grid.Column="2" VerticalAlignment="Center">
                  <TextBlock Style="{StaticResource Label}" Text="{DynamicResource L_CardLatest}"/>
                  <TextBlock x:Name="TxtLatest" ToolTip="{Binding Text, RelativeSource={RelativeSource Self}}" FontFamily="{StaticResource FontHead}" FontSize="21" FontWeight="SemiBold"
                             Foreground="{DynamicResource BrAccentText}" TextTrimming="CharacterEllipsis" Margin="0,5,0,0"/>
                </StackPanel>
                <Button x:Name="BtnUpdate" Grid.Column="3" Tag="&#xE896;" Content="{DynamicResource L_BtnUpdate}"
                        Style="{StaticResource BtnPrimary}" Padding="20,12" Margin="16,0,0,0" VerticalAlignment="Center"/>
              </Grid>
            </Grid>
          </Border>

          <Grid Grid.Row="1" Grid.ColumnSpan="2" Margin="4,0,0,6">
            <TextBlock x:Name="TxtListInfo" Style="{StaticResource Label}" VerticalAlignment="Center"/>
            <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
              <Button x:Name="BtnReload" Tag="&#xE72C;" Content="{DynamicResource L_BtnReload}" Style="{StaticResource BtnGhost}"/>
              <Button x:Name="BtnMore" Tag="&#xE70D;" Content="{DynamicResource L_BtnMore}" Style="{StaticResource BtnGhost}" Margin="4,0,0,0"/>
            </StackPanel>
          </Grid>

          <Border Grid.Row="2" Style="{StaticResource Card}" Padding="8,10,6,10">
            <ListBox x:Name="List" Foreground="{DynamicResource BrText}" Background="Transparent" BorderThickness="0"
                     ItemContainerStyle="{StaticResource LbItemLine}"
                     ScrollViewer.HorizontalScrollBarVisibility="Disabled">
              <ListBox.ItemTemplate>
                <DataTemplate>
                  <Grid>
                    <Grid.ColumnDefinitions>
                      <ColumnDefinition Width="26"/>
                      <ColumnDefinition Width="*"/>
                      <ColumnDefinition Width="Auto"/>
                      <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <!-- Zeitleiste: neueste = gruen, installiert = Akzent -->
                    <Rectangle Width="2" Fill="{DynamicResource BrLine}" HorizontalAlignment="Center"/>
                    <Ellipse Width="11" Height="11" Fill="{DynamicResource BrPanel}" Stroke="{DynamicResource BrMuted}" StrokeThickness="2"
                             HorizontalAlignment="Center" VerticalAlignment="Center"/>
                    <Ellipse Width="13" Height="13" Fill="{DynamicResource BrBadgeNewFg}" Visibility="{Binding NewBadge}"
                             HorizontalAlignment="Center" VerticalAlignment="Center"/>
                    <Ellipse Width="13" Height="13" Fill="{DynamicResource BrAccent}" Visibility="{Binding InstBadge}"
                             HorizontalAlignment="Center" VerticalAlignment="Center"/>
                    <StackPanel Grid.Column="1" VerticalAlignment="Center" Margin="10,10,0,10">
                      <TextBlock FontFamily="{StaticResource FontHead}" Text="{Binding Tag}" Foreground="{DynamicResource BrText}" FontSize="14.5" FontWeight="SemiBold"
                                 TextTrimming="CharacterEllipsis"/>
                      <TextBlock Text="{Binding Date}" Foreground="{DynamicResource BrMuted}" FontSize="12" Margin="0,2,0,0"/>
                    </StackPanel>
                    <Border Grid.Column="2" Visibility="{Binding NewBadge}" Background="{DynamicResource BrBadgeNewBg}"
                            CornerRadius="10" Padding="9,3" Margin="10,0,0,0" VerticalAlignment="Center">
                      <TextBlock FontFamily="{StaticResource FontHead}" Text="{DynamicResource L_CardLatest}" FontSize="10" FontWeight="Bold" Foreground="{DynamicResource BrBadgeNewFg}"/>
                    </Border>
                    <Border Grid.Column="3" Visibility="{Binding InstBadge}" Background="{DynamicResource BrBadgeInstBg}"
                            CornerRadius="10" Padding="9,3" Margin="6,0,0,0" VerticalAlignment="Center">
                      <TextBlock FontFamily="{StaticResource FontHead}" Text="{DynamicResource L_CardInstalled}" FontSize="10" FontWeight="Bold" Foreground="{DynamicResource BrAccentText}"/>
                    </Border>
                  </Grid>
                </DataTemplate>
              </ListBox.ItemTemplate>
            </ListBox>
          </Border>

          <Border x:Name="PanelNotesSide" Grid.Row="2" Grid.Column="1" Visibility="Collapsed" Style="{StaticResource Card}"
                  Padding="20,16" Margin="12,0,0,0"/>

          <StackPanel Grid.Row="3" Grid.ColumnSpan="2" Orientation="Horizontal" Margin="0,12,0,0">
            <Button x:Name="BtnInstallSel" Tag="&#xE896;" Content="{DynamicResource L_BtnInstallSel}" Style="{StaticResource Btn}"/>
            <Button x:Name="BtnRestore" Tag="&#xE81C;" Content="{DynamicResource L_BtnRestore}" Style="{StaticResource Btn}" Margin="8,0,0,0"/>
          </StackPanel>
        </Grid>

        <!-- Seite: Patchnotes -->
        <Border x:Name="PanelNotes" Visibility="Collapsed" Style="{StaticResource Card}" Padding="24,20">
          <Border.RenderTransform>
            <TranslateTransform/>
          </Border.RenderTransform>
          <Grid x:Name="NotesContent">
            <Grid.RowDefinitions>
              <RowDefinition Height="Auto"/>
              <RowDefinition Height="*"/>
            </Grid.RowDefinitions>
            <Grid Margin="0,0,0,14">
              <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
              </Grid.ColumnDefinitions>
              <StackPanel Margin="0,0,12,0">
                <TextBlock Style="{StaticResource Label}" Text="{DynamicResource L_NotesHeader}"/>
                <TextBlock FontFamily="{StaticResource FontHead}" x:Name="TxtNotesTitle" FontSize="20" FontWeight="SemiBold"
                           TextTrimming="CharacterEllipsis" Margin="0,4,0,0"/>
                <TextBlock x:Name="TxtNotesHint" Text="{DynamicResource L_NotesHintPage}" Style="{StaticResource Hint}" Margin="0,3,0,0"/>
              </StackPanel>
              <Button x:Name="BtnNotesWeb" Grid.Column="1" Tag="&#xE774;" Content="{DynamicResource L_NotesWeb}" Style="{StaticResource Btn}"
                      Padding="12,7" VerticalAlignment="Top"/>
            </Grid>
            <Border Grid.Row="1" Height="1" Background="{DynamicResource BrLine}" VerticalAlignment="Top"/>
            <TextBox x:Name="TxtNotes" Grid.Row="1" IsReadOnly="True" TextWrapping="Wrap" Margin="0,14,0,0"
                     VerticalScrollBarVisibility="Auto" Background="Transparent" BorderThickness="0"
                     Padding="0" FontSize="14"/>
          </Grid>
        </Border>

        <!-- Seite: Spiele (Kacheln) -->
        <Grid x:Name="PanelGames" Visibility="Collapsed">
          <Grid.RenderTransform>
            <TranslateTransform/>
          </Grid.RenderTransform>
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
          </Grid.RowDefinitions>

          <Grid Grid.Row="0" Margin="0,0,0,14">
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="3*" MaxWidth="300"/>
              <ColumnDefinition Width="Auto"/>
              <ColumnDefinition Width="*"/>
              <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <Grid>
              <TextBox x:Name="TxtGameSearch" Padding="36,8,10,8"/>
              <TextBlock Text="&#xE721;" FontFamily="{StaticResource FontIcon}" FontSize="13" Foreground="{DynamicResource BrMuted}"
                         VerticalAlignment="Center" Margin="13,0,0,0" IsHitTestVisible="False"/>
              <TextBlock x:Name="TxtGameSearchHint" Text="{DynamicResource L_GamesSearch}" Foreground="{DynamicResource BrMuted}"
                         VerticalAlignment="Center" Margin="37,0,0,0" IsHitTestVisible="False"/>
            </Grid>
            <!-- Reihenfolge: nach Name oder zuletzt gespielt -->
            <ComboBox x:Name="CmbGameSort" Grid.Column="1" SelectedValuePath="Tag" MinWidth="170" Margin="10,0,0,0" VerticalAlignment="Center"/>
            <StackPanel Grid.Column="3" Orientation="Horizontal" VerticalAlignment="Center" HorizontalAlignment="Right">
              <TextBlock x:Name="TxtGamesInfo" Style="{StaticResource Label}" VerticalAlignment="Center" Margin="12,0,8,0"/>
              <Button x:Name="BtnGamesReload" Tag="&#xE72C;" Content="{DynamicResource L_BtnReload}" Style="{StaticResource BtnGhost}"/>
            </StackPanel>
          </Grid>

          <!-- Weiterspielen: das zuletzt gestartete Spiel (aus Edens launched.json) -->
          <Border x:Name="GameContinue" Grid.Row="1" Visibility="Collapsed" CornerRadius="16" BorderThickness="1" Margin="0,0,0,14"
                  Background="{DynamicResource BrCard}" BorderBrush="{DynamicResource BrLine}">
            <Grid>
              <Border CornerRadius="15" Background="{DynamicResource GrHero}"/>
              <Grid Margin="12,12,16,12">
                <Grid.ColumnDefinitions>
                  <ColumnDefinition Width="Auto"/>
                  <ColumnDefinition Width="*"/>
                  <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <Grid Width="58" Height="58">
                  <Border x:Name="ContTile" CornerRadius="12">
                    <Viewbox StretchDirection="DownOnly" Margin="7,0">
                      <TextBlock x:Name="ContAbbr" FontFamily="{StaticResource FontHead}" FontSize="24" FontWeight="Bold" Foreground="#F5FFFFFF"/>
                    </Viewbox>
                  </Border>
                  <Border x:Name="ContImg" CornerRadius="12"/>
                </Grid>
                <StackPanel Grid.Column="1" Margin="14,0,12,0" VerticalAlignment="Center">
                  <TextBlock Style="{StaticResource Label}" Text="{DynamicResource L_GamesSortRecent}"/>
                  <TextBlock x:Name="TxtContName" FontFamily="{StaticResource FontHead}" FontSize="18" FontWeight="SemiBold" TextTrimming="CharacterEllipsis" Margin="0,3,0,0"
                             ToolTip="{Binding Text, RelativeSource={RelativeSource Self}}"/>
                  <TextBlock x:Name="TxtContInfo" Style="{StaticResource Hint}" TextWrapping="NoWrap" TextTrimming="CharacterEllipsis" Margin="0,2,0,0"/>
                </StackPanel>
                <Button x:Name="BtnGameContinue" Grid.Column="2" Tag="&#xE768;" Content="{DynamicResource L_GamesContinue}"
                        Style="{StaticResource BtnPrimary}" Padding="18,11" VerticalAlignment="Center"/>
              </Grid>
            </Grid>
          </Border>

          <Grid Grid.Row="2">
            <ListBox x:Name="ListGames" Foreground="{DynamicResource BrText}" Background="Transparent" BorderThickness="0" Padding="0"
                     ItemContainerStyle="{StaticResource GameTile}" Margin="-2,0,-8,0"
                     ScrollViewer.HorizontalScrollBarVisibility="Disabled" ScrollViewer.CanContentScroll="False">
              <ListBox.ItemsPanel>
                <ItemsPanelTemplate>
                  <WrapPanel Margin="4,6,0,0"/>
                </ItemsPanelTemplate>
              </ListBox.ItemsPanel>
              <ListBox.ItemTemplate>
                <DataTemplate>
                  <StackPanel ToolTip="{Binding PlayedTip}" Background="Transparent">
                    <Grid Height="130">
                      <!-- Ohne Cover: Kuerzel aus dem Namen auf einer Farbe, die fuer jedes Spiel anders ist -->
                      <Border CornerRadius="10" Background="{Binding TileBrush}">
                        <Viewbox StretchDirection="DownOnly" Margin="12,0">
                          <TextBlock Text="{Binding Abbr}" FontFamily="{StaticResource FontHead}" FontSize="48" FontWeight="Bold"
                                     Foreground="#F5FFFFFF" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Viewbox>
                      </Border>
                      <Border CornerRadius="10">
                        <Border.Background>
                          <ImageBrush ImageSource="{Binding IconImg}" Stretch="UniformToFill"/>
                        </Border.Background>
                      </Border>
                      <!-- Favorit: Stern oben rechts, Klick schaltet um (Handler am ListGames, erkannt ueber Tag="fav") -->
                      <Button Tag="fav" Focusable="False" Cursor="Hand" HorizontalAlignment="Right" VerticalAlignment="Top" Margin="0,6,6,0"
                              ToolTip="{DynamicResource L_GamesFavTip}">
                        <Button.Template>
                          <ControlTemplate TargetType="Button">
                            <Grid x:Name="g" Width="30" Height="30" Opacity="0" RenderTransformOrigin="0.5,0.5">
                              <Grid.RenderTransform>
                                <ScaleTransform x:Name="fsc" ScaleX="1" ScaleY="1"/>
                              </Grid.RenderTransform>
                              <Ellipse Fill="#B0101216"/>
                              <TextBlock x:Name="st" Text="&#xE734;" FontFamily="{StaticResource FontIcon}" FontSize="14"
                                         Foreground="#FFFFFF" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                            </Grid>
                            <ControlTemplate.Triggers>
                              <DataTrigger Binding="{Binding IsMouseOver, RelativeSource={RelativeSource AncestorType=ListBoxItem}}" Value="True">
                                <Setter TargetName="g" Property="Opacity" Value="0.9"/>
                              </DataTrigger>
                              <DataTrigger Binding="{Binding IsFav}" Value="True">
                                <Setter TargetName="st" Property="Text" Value="&#xE735;"/>
                                <Setter TargetName="st" Property="Foreground" Value="#FFD166"/>
                                <Setter TargetName="g" Property="Opacity" Value="1"/>
                              </DataTrigger>
                              <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="g" Property="Opacity" Value="1"/>
                                <Trigger.EnterActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="fsc" Storyboard.TargetProperty="ScaleX" To="1.18" Duration="0:0:0.18"><DoubleAnimation.EasingFunction><BackEase EasingMode="EaseOut" Amplitude="0.9"/></DoubleAnimation.EasingFunction></DoubleAnimation><DoubleAnimation Storyboard.TargetName="fsc" Storyboard.TargetProperty="ScaleY" To="1.18" Duration="0:0:0.18"><DoubleAnimation.EasingFunction><BackEase EasingMode="EaseOut" Amplitude="0.9"/></DoubleAnimation.EasingFunction></DoubleAnimation></Storyboard></BeginStoryboard></Trigger.EnterActions>
                                <Trigger.ExitActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="fsc" Storyboard.TargetProperty="ScaleX" To="1" Duration="0:0:0.16"/><DoubleAnimation Storyboard.TargetName="fsc" Storyboard.TargetProperty="ScaleY" To="1" Duration="0:0:0.16"/></Storyboard></BeginStoryboard></Trigger.ExitActions>
                              </Trigger>
                            </ControlTemplate.Triggers>
                          </ControlTemplate>
                        </Button.Template>
                      </Button>
                    </Grid>
                    <TextBlock Text="{Binding Name}" Foreground="{DynamicResource BrText}" FontFamily="{StaticResource FontHead}" FontSize="13.5" FontWeight="SemiBold"
                               TextWrapping="Wrap" LineHeight="17" Margin="2,9,2,0"/>
                    <TextBlock Text="{Binding Info}" Foreground="{DynamicResource BrMuted}" FontSize="11.5" Margin="2,2,2,1" TextTrimming="CharacterEllipsis"/>
                  </StackPanel>
                </DataTemplate>
              </ListBox.ItemTemplate>
            </ListBox>
            <TextBlock x:Name="TxtGamesEmpty" Style="{StaticResource Hint}" FontSize="13" TextAlignment="Center"
                       HorizontalAlignment="Center" VerticalAlignment="Center" MaxWidth="420" Visibility="Collapsed"/>
          </Grid>

          <Border Grid.Row="3" Style="{StaticResource Card}" Padding="12,10,18,10" Margin="0,10,0,0">
            <StackPanel Orientation="Horizontal">
              <Button x:Name="BtnGameStart" Tag="&#xE768;" Content="{DynamicResource L_GamesStart}" Style="{StaticResource BtnPrimary}" IsEnabled="False"/>
              <CheckBox x:Name="ChkGamesFull" Content="{DynamicResource L_GamesFull}" VerticalAlignment="Center" Margin="18,0,0,0"/>
              <CheckBox x:Name="ChkGamesClose" Content="{DynamicResource L_GamesClose}" VerticalAlignment="Center" Margin="20,0,0,0"/>
            </StackPanel>
          </Border>
        </Grid>

        <!-- Seite: Mods -->
        <Grid x:Name="PanelMods" Visibility="Collapsed">
          <Grid.RenderTransform>
            <TranslateTransform/>
          </Grid.RenderTransform>
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
          </Grid.RowDefinitions>

          <Grid Grid.Row="0" Margin="4,0,0,8">
            <TextBlock x:Name="TxtModsInfo" Style="{StaticResource Label}" VerticalAlignment="Center"/>
            <Button x:Name="BtnModsReload" Tag="&#xE72C;" Content="{DynamicResource L_BtnReload}" Style="{StaticResource BtnGhost}" HorizontalAlignment="Right"/>
          </Grid>

          <Border x:Name="ModsBanner" Grid.Row="1" Visibility="Collapsed" Style="{StaticResource Banner}" Margin="0,0,0,10">
            <StackPanel Orientation="Horizontal">
              <TextBlock Text="&#xE7BA;" FontFamily="{StaticResource FontIcon}" FontSize="14" Foreground="{DynamicResource BrAccentText}" VerticalAlignment="Center"/>
              <TextBlock Text="{DynamicResource L_ModsEdenRunning}" Foreground="{DynamicResource BrText}" Margin="10,0,0,0" VerticalAlignment="Center" TextWrapping="Wrap"/>
            </StackPanel>
          </Border>

          <Grid Grid.Row="2">
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="290"/>
              <ColumnDefinition Width="12"/>
              <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>

            <Border Grid.Column="0" Style="{StaticResource Card}" Padding="8">
              <ListBox x:Name="ListModGames" Foreground="{DynamicResource BrText}" Background="Transparent" BorderThickness="0"
                       ItemContainerStyle="{StaticResource LbItem}" ItemTemplate="{StaticResource GameRow}"
                       ScrollViewer.HorizontalScrollBarVisibility="Disabled"/>
            </Border>

            <Border Grid.Column="2" Style="{StaticResource Card}" Padding="0">
              <Grid>
                <Grid.RowDefinitions>
                  <RowDefinition Height="Auto"/>
                  <RowDefinition Height="*"/>
                </Grid.RowDefinitions>
                <Border CornerRadius="15,15,0,0" Background="{DynamicResource GrHero}"/>
                <StackPanel Margin="20,16,16,14">
                  <TextBlock x:Name="TxtModGameTitle" FontFamily="{StaticResource FontHead}" FontSize="19" FontWeight="SemiBold" TextTrimming="CharacterEllipsis"/>
                  <TextBlock x:Name="TxtModGameSub" Style="{StaticResource Hint}" TextWrapping="NoWrap" TextTrimming="CharacterEllipsis"
                             FontFamily="{StaticResource FontMono}" Margin="0,2,0,12"/>
                  <StackPanel Orientation="Horizontal">
                    <Button x:Name="BtnModAdd" Tag="&#xE710;" Content="{DynamicResource L_ModsAdd}" Style="{StaticResource BtnPrimary}" Padding="14,8"/>
                    <Button x:Name="BtnModFolder" Tag="&#xE838;" Content="{DynamicResource L_ModsFolder}" Style="{StaticResource BtnGhost}" Margin="8,0,0,0"/>
                  </StackPanel>
                </StackPanel>
                <Border Grid.Row="1" Height="1" Background="{DynamicResource BrLine}" VerticalAlignment="Top"/>
                <ListBox x:Name="ListMods" Grid.Row="1" Margin="8,8,8,8" Foreground="{DynamicResource BrText}" Background="Transparent" BorderThickness="0"
                         ItemContainerStyle="{StaticResource LbRow}" ScrollViewer.HorizontalScrollBarVisibility="Disabled">
                  <ListBox.ItemTemplate>
                    <DataTemplate>
                      <Grid>
                        <Grid.ColumnDefinitions>
                          <ColumnDefinition Width="Auto"/>
                          <ColumnDefinition Width="*"/>
                          <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <CheckBox Uid="toggle" Style="{StaticResource Switch}" IsChecked="{Binding Enabled, Mode=OneWay}" VerticalAlignment="Center"/>
                        <StackPanel Grid.Column="1" Margin="14,0,10,0" VerticalAlignment="Center">
                          <TextBlock Text="{Binding Name}" Foreground="{DynamicResource BrText}" FontFamily="{StaticResource FontHead}" FontSize="14"
                                     FontWeight="SemiBold" TextTrimming="CharacterEllipsis"/>
                          <TextBlock Text="{Binding Info}" Foreground="{DynamicResource BrMuted}" FontSize="11.5" Margin="0,2,0,0"/>
                        </StackPanel>
                        <Button Grid.Column="2" Uid="delete" Tag="&#xE74D;" Content="{DynamicResource L_ModsDelete}" Style="{StaticResource BtnGhost}"
                                VerticalAlignment="Center"/>
                      </Grid>
                    </DataTemplate>
                  </ListBox.ItemTemplate>
                </ListBox>
                <TextBlock x:Name="TxtModsEmpty" Grid.Row="1" Style="{StaticResource Hint}" FontSize="13" TextAlignment="Center"
                           HorizontalAlignment="Center" VerticalAlignment="Center" MaxWidth="360" Visibility="Collapsed"/>
              </Grid>
            </Border>
          </Grid>
        </Grid>

        <!-- Seite: Updates/DLC (externe Inhaltsordner von Eden) -->
        <Grid x:Name="PanelContent" Visibility="Collapsed">
          <Grid.RenderTransform>
            <TranslateTransform/>
          </Grid.RenderTransform>
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
          </Grid.RowDefinitions>

          <Grid Grid.Row="0" Margin="4,0,0,8">
            <TextBlock x:Name="TxtContentInfo" Style="{StaticResource Label}" VerticalAlignment="Center"/>
            <Button x:Name="BtnContentReload" Tag="&#xE72C;" Content="{DynamicResource L_BtnReload}" Style="{StaticResource BtnGhost}" HorizontalAlignment="Right"/>
          </Grid>

          <Border x:Name="ContentBanner" Grid.Row="1" Visibility="Collapsed" Style="{StaticResource Banner}" Margin="0,0,0,10">
            <StackPanel Orientation="Horizontal">
              <TextBlock Text="&#xE7BA;" FontFamily="{StaticResource FontIcon}" FontSize="14" Foreground="{DynamicResource BrAccentText}" VerticalAlignment="Center"/>
              <TextBlock Text="{DynamicResource L_SysEdenRunning}" Foreground="{DynamicResource BrText}" Margin="10,0,0,0" VerticalAlignment="Center" TextWrapping="Wrap"/>
            </StackPanel>
          </Border>

          <Grid Grid.Row="2">
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="290"/>
              <ColumnDefinition Width="12"/>
              <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>

            <Border Grid.Column="0" Style="{StaticResource Card}" Padding="8">
              <ListBox x:Name="ListContentGames" Foreground="{DynamicResource BrText}" Background="Transparent" BorderThickness="0"
                       ItemContainerStyle="{StaticResource LbItem}" ItemTemplate="{StaticResource GameRow}"
                       ScrollViewer.HorizontalScrollBarVisibility="Disabled"/>
            </Border>

            <Border Grid.Column="2" Style="{StaticResource Card}" Padding="0">
              <Grid>
                <Grid.RowDefinitions>
                  <RowDefinition Height="Auto"/>
                  <RowDefinition Height="*"/>
                </Grid.RowDefinitions>
                <Border CornerRadius="15,15,0,0" Background="{DynamicResource GrHero}"/>
                <StackPanel Margin="20,16,16,14">
                  <TextBlock x:Name="TxtContentGameTitle" FontFamily="{StaticResource FontHead}" FontSize="19" FontWeight="SemiBold" TextTrimming="CharacterEllipsis"/>
                  <TextBlock x:Name="TxtContentGameSub" Style="{StaticResource Hint}" TextWrapping="NoWrap" TextTrimming="CharacterEllipsis"
                             FontFamily="{StaticResource FontMono}" Margin="0,2,0,12"/>
                  <StackPanel Orientation="Horizontal">
                    <Button x:Name="BtnContentAdd" Tag="&#xE710;" Content="{DynamicResource L_ContentAdd}" Style="{StaticResource BtnPrimary}" Padding="14,8"/>
                    <Button x:Name="BtnContentFolder" Tag="&#xE838;" Content="{DynamicResource L_ContentFolder}" Style="{StaticResource BtnGhost}" Margin="8,0,0,0"/>
                  </StackPanel>
                </StackPanel>
                <Border Grid.Row="1" Height="1" Background="{DynamicResource BrLine}" VerticalAlignment="Top"/>
                <ListBox x:Name="ListContent" Grid.Row="1" Margin="8,8,8,8" Foreground="{DynamicResource BrText}" Background="Transparent" BorderThickness="0"
                         ItemContainerStyle="{StaticResource LbRow}" ScrollViewer.HorizontalScrollBarVisibility="Disabled">
                  <ListBox.ItemTemplate>
                    <DataTemplate>
                      <Grid>
                        <Grid.ColumnDefinitions>
                          <ColumnDefinition Width="Auto"/>
                          <ColumnDefinition Width="*"/>
                          <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <CheckBox Uid="toggle" IsChecked="{Binding Enabled, Mode=OneWay}" VerticalAlignment="Center">
                          <CheckBox.Style>
                            <Style TargetType="CheckBox" BasedOn="{StaticResource Switch}">
                              <Style.Triggers>
                                <DataTrigger Binding="{Binding CanToggle}" Value="False">
                                  <Setter Property="Visibility" Value="Hidden"/>
                                </DataTrigger>
                              </Style.Triggers>
                            </Style>
                          </CheckBox.Style>
                        </CheckBox>
                        <StackPanel Grid.Column="1" Margin="14,0,10,0" VerticalAlignment="Center">
                          <TextBlock Text="{Binding Name}" Foreground="{DynamicResource BrText}" FontFamily="{StaticResource FontHead}" FontSize="14"
                                     FontWeight="SemiBold" TextTrimming="CharacterEllipsis"/>
                          <TextBlock Text="{Binding Info}" Foreground="{DynamicResource BrMuted}" FontSize="11.5" Margin="0,2,0,0" TextWrapping="Wrap"/>
                        </StackPanel>
                        <Button Grid.Column="2" Uid="delete" Tag="&#xE74D;" Content="{DynamicResource L_ContentDelete}" Style="{StaticResource BtnGhost}"
                                VerticalAlignment="Center"/>
                      </Grid>
                    </DataTemplate>
                  </ListBox.ItemTemplate>
                </ListBox>
                <TextBlock x:Name="TxtContentEmpty" Grid.Row="1" Style="{StaticResource Hint}" FontSize="13" TextAlignment="Center"
                           HorizontalAlignment="Center" VerticalAlignment="Center" MaxWidth="360" Visibility="Collapsed"/>
              </Grid>
            </Border>
          </Grid>
        </Grid>

        <!-- Seite: Spieldaten (Spielstaende + Shader-Cache) -->
        <Grid x:Name="PanelSaves" Visibility="Collapsed">
          <Grid.RenderTransform>
            <TranslateTransform/>
          </Grid.RenderTransform>
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
          </Grid.RowDefinitions>

          <Grid Grid.Row="0" Margin="4,0,0,8">
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="*"/>
              <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <TextBlock x:Name="TxtSavesInfo" Style="{StaticResource Label}" VerticalAlignment="Center" TextTrimming="CharacterEllipsis"/>
            <StackPanel Grid.Column="1" Orientation="Horizontal">
              <Button x:Name="BtnShaderAll" Tag="&#xE74D;" Content="{DynamicResource L_SavesShaderAll}" Style="{StaticResource BtnGhost}" ToolTip="{DynamicResource L_SavesShaderHint}"/>
              <Button x:Name="BtnSaveBackupDir" Tag="&#xE838;" Content="{DynamicResource L_SavesBackupDir}" Style="{StaticResource BtnGhost}" Margin="4,0,0,0"/>
              <Button x:Name="BtnSavesReload" Tag="&#xE72C;" Content="{DynamicResource L_BtnReload}" Style="{StaticResource BtnGhost}" Margin="4,0,0,0"/>
            </StackPanel>
          </Grid>

          <Border x:Name="SavesBanner" Grid.Row="1" Visibility="Collapsed" Style="{StaticResource Banner}" Margin="0,0,0,10">
            <StackPanel Orientation="Horizontal">
              <TextBlock Text="&#xE7BA;" FontFamily="{StaticResource FontIcon}" FontSize="14" Foreground="{DynamicResource BrAccentText}" VerticalAlignment="Center"/>
              <TextBlock Text="{DynamicResource L_SysEdenRunning}" Foreground="{DynamicResource BrText}" Margin="10,0,0,0" VerticalAlignment="Center" TextWrapping="Wrap"/>
            </StackPanel>
          </Border>

          <Grid Grid.Row="2">
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="290"/>
              <ColumnDefinition Width="12"/>
              <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>

            <Border Grid.Column="0" Style="{StaticResource Card}" Padding="8">
              <ListBox x:Name="ListSaveGames" Foreground="{DynamicResource BrText}" Background="Transparent" BorderThickness="0"
                       ItemContainerStyle="{StaticResource LbItem}" ItemTemplate="{StaticResource GameRow}"
                       ScrollViewer.HorizontalScrollBarVisibility="Disabled"/>
            </Border>

            <Border Grid.Column="2" Style="{StaticResource Card}" Padding="0">
              <Grid>
                <Grid.RowDefinitions>
                  <RowDefinition Height="Auto"/>
                  <RowDefinition Height="Auto"/>
                  <RowDefinition Height="*"/>
                </Grid.RowDefinitions>
                <Border CornerRadius="15,15,0,0" Background="{DynamicResource GrHero}"/>
                <StackPanel Margin="20,16,14,10">
                  <Grid>
                    <Grid.ColumnDefinitions>
                      <ColumnDefinition Width="*"/>
                      <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <StackPanel VerticalAlignment="Center">
                      <TextBlock x:Name="TxtSaveGameTitle" FontFamily="{StaticResource FontHead}" FontSize="19" FontWeight="SemiBold" TextTrimming="CharacterEllipsis"/>
                      <TextBlock x:Name="TxtSaveGameSub" Style="{StaticResource Hint}" TextWrapping="NoWrap" TextTrimming="CharacterEllipsis"
                                 FontFamily="{StaticResource FontMono}" Margin="0,2,0,0"/>
                    </StackPanel>
                    <Button x:Name="BtnSaveBackup" Grid.Column="1" Tag="&#xE74E;" Content="{DynamicResource L_SavesBackupNow}" Style="{StaticResource BtnPrimary}"
                            Padding="14,8" VerticalAlignment="Center" Margin="10,0,0,0"/>
                  </Grid>
                  <!-- Spielstand -->
                  <Grid Margin="0,12,0,0">
                    <Grid.ColumnDefinitions>
                      <ColumnDefinition Width="Auto"/>
                      <ColumnDefinition Width="*"/>
                      <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <TextBlock Text="&#xE74E;" FontFamily="{StaticResource FontIcon}" FontSize="14" Foreground="{DynamicResource BrAccentText}" VerticalAlignment="Center"/>
                    <TextBlock x:Name="TxtSaveState" Grid.Column="1" Foreground="{DynamicResource BrText}" FontSize="12.5" Margin="10,0,8,0"
                               VerticalAlignment="Center" TextTrimming="CharacterEllipsis"/>
                    <Button x:Name="BtnSaveFolder" Grid.Column="2" Tag="&#xE838;" Content="{DynamicResource L_SavesOpenFolder}" Style="{StaticResource BtnGhost}"/>
                  </Grid>
                  <!-- Shader-Cache -->
                  <Grid Margin="0,2,0,0" ToolTip="{DynamicResource L_SavesShaderHint}" Background="Transparent">
                    <Grid.ColumnDefinitions>
                      <ColumnDefinition Width="Auto"/>
                      <ColumnDefinition Width="*"/>
                      <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <TextBlock Text="&#xE950;" FontFamily="{StaticResource FontIcon}" FontSize="14" Foreground="{DynamicResource BrAccentText}" VerticalAlignment="Center"/>
                    <TextBlock x:Name="TxtShaderState" Grid.Column="1" Foreground="{DynamicResource BrText}" FontSize="12.5" Margin="10,0,8,0"
                               VerticalAlignment="Center" TextTrimming="CharacterEllipsis"/>
                    <Button x:Name="BtnShaderDelete" Grid.Column="2" Tag="&#xE74D;" Content="{DynamicResource L_SavesShaderDelete}" Style="{StaticResource BtnGhost}"/>
                  </Grid>
                </StackPanel>
                <Border Grid.Row="1" Height="1" Background="{DynamicResource BrLine}"/>
                <Grid Grid.Row="2">
                  <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="*"/>
                  </Grid.RowDefinitions>
                  <TextBlock Text="{DynamicResource L_SavesBackupsTitle}" Style="{StaticResource Label}" Margin="20,12,0,2"/>
                  <ListBox x:Name="ListSaveBackups" Grid.Row="1" Margin="8,4,8,8" Foreground="{DynamicResource BrText}" Background="Transparent" BorderThickness="0"
                           ScrollViewer.HorizontalScrollBarVisibility="Disabled">
                    <ListBox.ItemContainerStyle>
                      <Style TargetType="ListBoxItem" BasedOn="{StaticResource LbRow}">
                        <Setter Property="Padding" Value="12,8,8,8"/>
                      </Style>
                    </ListBox.ItemContainerStyle>
                    <ListBox.ItemTemplate>
                      <DataTemplate>
                        <Grid>
                          <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="Auto"/>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                            <ColumnDefinition Width="Auto"/>
                          </Grid.ColumnDefinitions>
                          <TextBlock Text="&#xE81C;" FontFamily="{StaticResource FontIcon}" FontSize="16" Foreground="{DynamicResource BrAccentText}" VerticalAlignment="Center"/>
                          <StackPanel Grid.Column="1" Margin="14,0,10,0" VerticalAlignment="Center">
                            <TextBlock Text="{Binding Name}" Foreground="{DynamicResource BrText}" FontFamily="{StaticResource FontHead}" FontSize="14"
                                       FontWeight="SemiBold" TextTrimming="CharacterEllipsis"/>
                            <TextBlock Text="{Binding Info}" Foreground="{DynamicResource BrMuted}" FontSize="11.5" Margin="0,2,0,0" TextWrapping="Wrap"/>
                          </StackPanel>
                          <Button Grid.Column="2" Uid="restore" Tag="&#xE777;" Content="{DynamicResource L_SavesRestore}" Style="{StaticResource BtnGhost}"
                                  VerticalAlignment="Center"/>
                          <Button Grid.Column="3" Uid="delete" Tag="&#xE74D;" Content="{DynamicResource L_SavesDelete}" Style="{StaticResource BtnGhost}"
                                  VerticalAlignment="Center" Margin="4,0,0,0"/>
                        </Grid>
                      </DataTemplate>
                    </ListBox.ItemTemplate>
                  </ListBox>
                  <TextBlock x:Name="TxtSaveBackupsEmpty" Grid.Row="1" Style="{StaticResource Hint}" FontSize="13" TextAlignment="Center"
                             HorizontalAlignment="Center" VerticalAlignment="Center" MaxWidth="360" Margin="0,0,0,20" Visibility="Collapsed"/>
                </Grid>
              </Grid>
            </Border>
          </Grid>
        </Grid>

        <!-- Seite: Firmware und Schluessel -->
        <Grid x:Name="PanelFirmware" Visibility="Collapsed">
          <Grid.RenderTransform>
            <TranslateTransform/>
          </Grid.RenderTransform>
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
          </Grid.RowDefinitions>

          <Border x:Name="FwBanner" Grid.Row="0" Visibility="Collapsed" Style="{StaticResource Banner}" Margin="0,0,0,10">
            <StackPanel Orientation="Horizontal">
              <TextBlock Text="&#xE7BA;" FontFamily="{StaticResource FontIcon}" FontSize="14" Foreground="{DynamicResource BrAccentText}" VerticalAlignment="Center"/>
              <TextBlock Text="{DynamicResource L_SysEdenRunning}" Foreground="{DynamicResource BrText}" Margin="10,0,0,0" VerticalAlignment="Center" TextWrapping="Wrap"/>
            </StackPanel>
          </Border>

          <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
            <StackPanel>
              <!-- Firmware -->
              <Border Style="{StaticResource Card}">
                <StackPanel>
                  <Grid Margin="0,0,0,14">
                    <Grid.ColumnDefinitions>
                      <ColumnDefinition Width="Auto"/>
                      <ColumnDefinition Width="*"/>
                      <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <Border Style="{StaticResource IconBadge}" Width="44" Height="44" CornerRadius="13">
                      <TextBlock Text="&#xE950;" Style="{StaticResource IconBadgeGlyph}" FontSize="20"/>
                    </Border>
                    <StackPanel Grid.Column="1" Margin="14,0,10,0" VerticalAlignment="Center">
                      <TextBlock Style="{StaticResource Label}" Text="{DynamicResource L_FwTitle}"/>
                      <TextBlock x:Name="TxtFwState" Style="{StaticResource FieldTitle}" FontSize="18" Margin="0,2,0,0"/>
                    </StackPanel>
                    <Button x:Name="BtnFwFolder" Grid.Column="2" Tag="&#xE838;" Content="{DynamicResource L_FwFolder}" Style="{StaticResource BtnGhost}"
                            VerticalAlignment="Top"/>
                  </Grid>
                  <TextBlock x:Name="TxtFwSub" Style="{StaticResource Hint}"/>
                  <Border x:Name="FwWarn" Visibility="Collapsed" Style="{StaticResource Banner}" Padding="12,8" Margin="0,12,0,0">
                    <StackPanel Orientation="Horizontal">
                      <TextBlock Text="&#xE7BA;" FontFamily="{StaticResource FontIcon}" FontSize="14" Foreground="{DynamicResource BrAccentText}" VerticalAlignment="Center"/>
                      <TextBlock x:Name="TxtFwWarn" Foreground="{DynamicResource BrText}" Margin="10,0,0,0" VerticalAlignment="Center" TextWrapping="Wrap"/>
                    </StackPanel>
                  </Border>
                  <StackPanel Orientation="Horizontal" Margin="0,16,0,0">
                    <Button x:Name="BtnFwZip" Tag="&#xE896;" Content="{DynamicResource L_FwInstallZip}" Style="{StaticResource BtnPrimary}" Padding="14,8"/>
                    <Button x:Name="BtnFwDir" Tag="&#xE8B7;" Content="{DynamicResource L_FwInstallDir}" Style="{StaticResource Btn}" Padding="14,8" Margin="8,0,0,0"/>
                    <Button x:Name="BtnFwDelete" Tag="&#xE74D;" Content="{DynamicResource L_FwDelete}" Style="{StaticResource BtnGhost}" Margin="8,0,0,0"/>
                  </StackPanel>
                  <TextBlock Text="{DynamicResource L_FwHint}" Style="{StaticResource Hint}" Margin="0,14,0,0"/>
                </StackPanel>
              </Border>

              <!-- Schluessel -->
              <Border Style="{StaticResource Card}" Margin="0,14,0,6">
                <StackPanel>
                  <Grid Margin="0,0,0,14">
                    <Grid.ColumnDefinitions>
                      <ColumnDefinition Width="Auto"/>
                      <ColumnDefinition Width="*"/>
                      <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <Border Style="{StaticResource IconBadge}" Width="44" Height="44" CornerRadius="13">
                      <TextBlock Text="&#xE8D7;" Style="{StaticResource IconBadgeGlyph}" FontSize="20"/>
                    </Border>
                    <StackPanel Grid.Column="1" Margin="14,0,10,0" VerticalAlignment="Center">
                      <TextBlock Style="{StaticResource Label}" Text="{DynamicResource L_KeysTitle}"/>
                      <TextBlock x:Name="TxtKeysState" Style="{StaticResource FieldTitle}" FontSize="18" Margin="0,2,0,0"/>
                    </StackPanel>
                    <Button x:Name="BtnKeysFolder" Grid.Column="2" Tag="&#xE838;" Content="{DynamicResource L_FwFolder}" Style="{StaticResource BtnGhost}"
                            VerticalAlignment="Top"/>
                  </Grid>
                  <TextBlock x:Name="TxtKeysSub" Style="{StaticResource Hint}"/>
                  <StackPanel Orientation="Horizontal" Margin="0,16,0,0">
                    <Button x:Name="BtnKeysInstall" Tag="&#xE896;" Content="{DynamicResource L_KeysInstall}" Style="{StaticResource BtnPrimary}" Padding="14,8"/>
                    <Button x:Name="BtnKeysDelete" Tag="&#xE74D;" Content="{DynamicResource L_KeysDelete}" Style="{StaticResource BtnGhost}" Margin="8,0,0,0"/>
                  </StackPanel>
                  <TextBlock Text="{DynamicResource L_KeysHint}" Style="{StaticResource Hint}" Margin="0,14,0,0"/>
                </StackPanel>
              </Border>
            </StackPanel>
          </ScrollViewer>
        </Grid>

        <!-- Seite: Einstellungen -->
        <Grid x:Name="PanelSettings" Visibility="Collapsed">
          <Grid.RenderTransform>
            <TranslateTransform/>
          </Grid.RenderTransform>
          <Grid.RowDefinitions>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
          </Grid.RowDefinitions>
          <ScrollViewer x:Name="SettingsScroll" VerticalScrollBarVisibility="Auto">
            <StackPanel Margin="0,0,10,0">

              <!-- Installation -->
              <Border Style="{StaticResource Card}" Margin="0,0,0,14">
                <StackPanel>
                  <StackPanel Orientation="Horizontal" Margin="0,0,0,18">
                    <Border Style="{StaticResource IconBadge}">
                      <TextBlock Text="&#xE8B7;" Style="{StaticResource IconBadgeGlyph}"/>
                    </Border>
                    <TextBlock Text="{DynamicResource L_GrpInstall}" FontFamily="{StaticResource FontHead}" FontSize="16" FontWeight="SemiBold" Margin="12,0,0,0" VerticalAlignment="Center"/>
                  </StackPanel>

                  <TextBlock Style="{StaticResource FieldTitle}" Text="{DynamicResource L_SetPath}"/>
                  <Grid Margin="0,7,0,4">
                    <Grid.ColumnDefinitions>
                      <ColumnDefinition Width="*"/>
                      <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <TextBox x:Name="TxtPath" Grid.Column="0"/>
                    <Button x:Name="BtnBrowse" Grid.Column="1" Tag="&#xE838;" Content="{DynamicResource L_SetBrowse}" Style="{StaticResource Btn}"
                            Padding="14,7" Margin="8,0,0,0"/>
                  </Grid>
                  <TextBlock x:Name="TxtSettingsFile" Style="{StaticResource Hint}" Margin="0,0,0,18"/>

                  <Grid>
                    <Grid.ColumnDefinitions>
                      <ColumnDefinition Width="3*"/>
                      <ColumnDefinition Width="18"/>
                      <ColumnDefinition Width="2*"/>
                    </Grid.ColumnDefinitions>
                    <StackPanel Grid.Column="0">
                      <TextBlock Style="{StaticResource FieldTitle}" Text="{DynamicResource L_SetVariant}"/>
                      <ComboBox x:Name="CmbVariant" SelectedValuePath="Tag" Margin="0,7,0,4"/>
                      <TextBlock Style="{StaticResource Hint}" Text="{DynamicResource L_SetVariantHint}"/>
                    </StackPanel>
                    <StackPanel Grid.Column="2">
                      <TextBlock Style="{StaticResource FieldTitle}" Text="{DynamicResource L_SetPages}"/>
                      <TextBox x:Name="TxtPages" Width="90" HorizontalAlignment="Left" Margin="0,7,0,0"/>
                    </StackPanel>
                  </Grid>

                  <StackPanel x:Name="PanelPattern" Visibility="Collapsed" Margin="0,18,0,0">
                    <TextBlock Style="{StaticResource FieldTitle}" Text="{DynamicResource L_SetPattern}"/>
                    <TextBox x:Name="TxtPattern" Margin="0,7,0,0" FontFamily="{StaticResource FontMono}"/>
                  </StackPanel>
                </StackPanel>
              </Border>

              <Grid Margin="0,0,0,14">
                <Grid.ColumnDefinitions>
                  <ColumnDefinition Width="*"/>
                  <ColumnDefinition Width="14"/>
                  <ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>

                <!-- Darstellung -->
                <Border Grid.Column="0" Style="{StaticResource Card}">
                  <StackPanel>
                    <StackPanel Orientation="Horizontal" Margin="0,0,0,18">
                      <Border Style="{StaticResource IconBadge}">
                        <TextBlock Text="&#xE790;" Style="{StaticResource IconBadgeGlyph}"/>
                      </Border>
                      <TextBlock Text="{DynamicResource L_GrpLook}" FontFamily="{StaticResource FontHead}" FontSize="16" FontWeight="SemiBold" Margin="12,0,0,0" VerticalAlignment="Center"/>
                    </StackPanel>

                    <TextBlock Style="{StaticResource FieldTitle}" Text="{DynamicResource L_SetTheme}"/>
                    <!-- Aktuelles Theme als kleine Vorschau; Klick oeffnet die Auswahl -->
                    <Button x:Name="BtnThemePick" Cursor="Hand" Margin="0,7,0,18" FocusVisualStyle="{x:Null}" HorizontalContentAlignment="Stretch">
                      <Button.Template>
                        <ControlTemplate TargetType="Button">
                          <Grid>
                            <Border x:Name="bd" Background="{DynamicResource BrPanel2}" BorderBrush="{DynamicResource BrLine}" BorderThickness="1" CornerRadius="12" Padding="10">
                              <Grid>
                                <Grid.ColumnDefinitions>
                                  <ColumnDefinition Width="Auto"/>
                                  <ColumnDefinition Width="*"/>
                                  <ColumnDefinition Width="Auto"/>
                                </Grid.ColumnDefinitions>
                                <Border Width="62" Height="42" CornerRadius="9" Background="{DynamicResource BrBg}" BorderBrush="{DynamicResource BrLine}" BorderThickness="1">
                                  <Grid>
                                    <Border Width="28" Height="9" CornerRadius="4.5" Background="{DynamicResource GrAccent}" HorizontalAlignment="Left" VerticalAlignment="Top" Margin="9,9,0,0"/>
                                    <Border Width="40" Height="4" CornerRadius="2" Background="{DynamicResource BrText}" Opacity="0.8" HorizontalAlignment="Left" VerticalAlignment="Top" Margin="9,25,0,0"/>
                                  </Grid>
                                </Border>
                                <ContentPresenter Grid.Column="1" Margin="13,0,8,0" VerticalAlignment="Center"/>
                                <TextBlock x:Name="chev" Grid.Column="2" Text="&#xE76C;" FontFamily="{StaticResource FontIcon}" FontSize="12"
                                           Foreground="{DynamicResource BrMuted}" VerticalAlignment="Center" Margin="0,0,6,0">
                                  <TextBlock.RenderTransform>
                                    <TranslateTransform x:Name="cx" X="0"/>
                                  </TextBlock.RenderTransform>
                                </TextBlock>
                              </Grid>
                            </Border>
                            <Border x:Name="hl" Background="{DynamicResource BrText}" CornerRadius="12" Opacity="0" IsHitTestVisible="False"/>
                          </Grid>
                          <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                              <Setter TargetName="bd" Property="BorderBrush" Value="{DynamicResource BrAccent}"/>
                              <Setter TargetName="chev" Property="Foreground" Value="{DynamicResource BrAccentText}"/>
                              <Trigger.EnterActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="hl" Storyboard.TargetProperty="Opacity" To="0.04" Duration="0:0:0.15"/><DoubleAnimation Storyboard.TargetName="cx" Storyboard.TargetProperty="X" To="4" Duration="0:0:0.2"><DoubleAnimation.EasingFunction><CubicEase EasingMode="EaseOut"/></DoubleAnimation.EasingFunction></DoubleAnimation></Storyboard></BeginStoryboard></Trigger.EnterActions>
                              <Trigger.ExitActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="hl" Storyboard.TargetProperty="Opacity" To="0" Duration="0:0:0.22"/><DoubleAnimation Storyboard.TargetName="cx" Storyboard.TargetProperty="X" To="0" Duration="0:0:0.2"/></Storyboard></BeginStoryboard></Trigger.ExitActions>
                            </Trigger>
                          </ControlTemplate.Triggers>
                        </ControlTemplate>
                      </Button.Template>
                      <StackPanel>
                        <TextBlock x:Name="TxtThemeName" FontFamily="{StaticResource FontHead}" FontWeight="SemiBold" FontSize="14" TextTrimming="CharacterEllipsis"/>
                        <TextBlock Text="{DynamicResource L_SetThemePick}" Foreground="{DynamicResource BrAccentText}" FontSize="12" Margin="0,2,0,0" TextTrimming="CharacterEllipsis"/>
                      </StackPanel>
                    </Button>

                    <TextBlock Style="{StaticResource FieldTitle}" Text="{DynamicResource L_SetLanguage}"/>
                    <ComboBox x:Name="CmbLang" SelectedValuePath="Tag" Margin="0,7,0,4" MaxDropDownHeight="380"/>
                    <TextBlock Style="{StaticResource Hint}" Text="{DynamicResource L_SetLanguageHint}" Margin="0,0,0,18"/>

                    <TextBlock Style="{StaticResource FieldTitle}" Text="{DynamicResource L_SetNotes}"/>
                    <ComboBox x:Name="CmbNotes" SelectedValuePath="Tag" Margin="0,7,0,0"/>
                  </StackPanel>
                </Border>

                <!-- Verhalten -->
                <Border Grid.Column="2" Style="{StaticResource Card}" Padding="20,20,20,12">
                  <StackPanel>
                    <StackPanel Orientation="Horizontal" Margin="0,0,0,10">
                      <Border Style="{StaticResource IconBadge}">
                        <TextBlock Text="&#xE9F5;" Style="{StaticResource IconBadgeGlyph}"/>
                      </Border>
                      <TextBlock Text="{DynamicResource L_GrpBehavior}" FontFamily="{StaticResource FontHead}" FontSize="16" FontWeight="SemiBold" Margin="12,0,0,0" VerticalAlignment="Center"/>
                    </StackPanel>
                    <CheckBox x:Name="ChkBackup" Content="{DynamicResource L_ChkBackup}" Style="{StaticResource SwitchRow}"/>
                    <CheckBox x:Name="ChkSaveAuto" Content="{DynamicResource L_ChkSaveAuto}" Style="{StaticResource SwitchRow}"/>
                    <CheckBox x:Name="ChkStart" Content="{DynamicResource L_ChkStart}" Style="{StaticResource SwitchRow}"/>
                    <CheckBox x:Name="ChkClose" Content="{DynamicResource L_ChkClose}" Style="{StaticResource SwitchRow}"/>
                    <CheckBox x:Name="ChkAuto" Content="{DynamicResource L_ChkAuto}" Style="{StaticResource SwitchRow}"/>
                    <CheckBox x:Name="ChkAutoInstall" Content="{DynamicResource L_ChkAutoInstall}" Style="{StaticResource SwitchRow}"/>
                  </StackPanel>
                </Border>
              </Grid>

              <!-- Updater selbst -->
              <Border Style="{StaticResource Card}" Margin="0,0,0,6" Padding="20,20,20,12">
                <StackPanel>
                  <Grid>
                    <Grid.ColumnDefinitions>
                      <ColumnDefinition Width="Auto"/>
                      <ColumnDefinition Width="*"/>
                      <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <Border Style="{StaticResource IconBadge}">
                      <TextBlock Text="&#xE895;" Style="{StaticResource IconBadgeGlyph}"/>
                    </Border>
                    <StackPanel Grid.Column="1" VerticalAlignment="Center" Margin="12,0,12,0">
                      <TextBlock Style="{StaticResource Label}" Text="{DynamicResource L_GrpUpdater}"/>
                      <TextBlock x:Name="TxtSelfVersion" FontFamily="{StaticResource FontHead}" FontSize="16" FontWeight="SemiBold" TextTrimming="CharacterEllipsis" Margin="0,2,0,0"/>
                      <TextBlock x:Name="TxtSelfState" Style="{StaticResource Hint}" Margin="0,2,0,0"/>
                    </StackPanel>
                    <StackPanel Grid.Column="2" Orientation="Horizontal" VerticalAlignment="Center">
                      <Button x:Name="BtnSelfNotes" Tag="&#xE774;" Content="{DynamicResource L_SelfBtnNotes}" Style="{StaticResource BtnGhost}"
                              Visibility="Collapsed" Margin="0,0,6,0"/>
                      <Button x:Name="BtnSelfCheck" Tag="&#xE72C;" Content="{DynamicResource L_SelfBtnCheck}" Style="{StaticResource Btn}" Padding="14,8"/>
                      <Button x:Name="BtnSelfInstall" Tag="&#xE896;" Content="{DynamicResource L_SelfBtnInstall}" Style="{StaticResource BtnPrimary}"
                              Padding="14,8" Margin="8,0,0,0" Visibility="Collapsed"/>
                    </StackPanel>
                  </Grid>
                  <CheckBox x:Name="ChkSelfUpdate" Content="{DynamicResource L_SelfChkStart}" Style="{StaticResource SwitchRow}" Margin="-10,12,-10,0"/>
                </StackPanel>
              </Border>
            </StackPanel>
          </ScrollViewer>
          <Button x:Name="BtnSave" Grid.Row="1" Tag="&#xE74E;" Content="{DynamicResource L_Save}" Style="{StaticResource BtnPrimary}"
                  HorizontalAlignment="Left" Padding="22,10" Margin="0,12,0,0"/>
        </Grid>
      </Grid>

      <!-- Aktivitaet: Status, Fortschritt, aufklappbares Log -->
      <Border Grid.Row="2" Style="{StaticResource Card}" Padding="0" CornerRadius="14" Margin="0,14,0,0">
        <Grid>
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
          </Grid.RowDefinitions>
          <Grid Margin="16,7,8,7">
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="Auto"/>
              <ColumnDefinition Width="*"/>
              <ColumnDefinition Width="Auto"/>
              <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <Ellipse x:Name="DotBusy" Width="8" Height="8" Fill="{DynamicResource BrMuted}" VerticalAlignment="Center"/>
            <TextBlock x:Name="TxtStatus" Grid.Column="1" Text="{DynamicResource L_StReady}" VerticalAlignment="Center" TextTrimming="CharacterEllipsis" Margin="11,0,0,0"/>
            <Button x:Name="BtnCancel" Grid.Column="2" Tag="&#xE711;" Content="{DynamicResource L_Cancel}" Style="{StaticResource Btn}"
                    Padding="12,5" Margin="8,0,0,0" Visibility="Collapsed"/>
            <Button x:Name="BtnLogToggle" Grid.Column="3" Tag="&#xE70D;" Content="{DynamicResource L_LogTitle}" Style="{StaticResource BtnGhost}"
                    Margin="8,0,0,0"/>
          </Grid>
          <ProgressBar x:Name="Pb" Grid.Row="1" Height="4" Minimum="0" Maximum="100" Value="0" Margin="16,0,16,10"
                       BorderThickness="0"/>
          <TextBox x:Name="TxtLog" Grid.Row="2" Height="130" Margin="12,0,12,12" IsReadOnly="True" Visibility="Collapsed"
                   FontFamily="{StaticResource FontMono}" FontSize="12" Background="{DynamicResource BrLog}"
                   VerticalScrollBarVisibility="Auto" TextWrapping="Wrap"/>
        </Grid>
      </Border>
    </Grid>

    <!-- Fensterknoepfe oben rechts -->
    <StackPanel Grid.ColumnSpan="2" Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Top">
      <Button x:Name="BtnWinMin" Tag="&#xE921;" Style="{StaticResource BtnCaption}"/>
      <Button x:Name="BtnWinMax" Tag="&#xE922;" Style="{StaticResource BtnCaption}"/>
      <Button x:Name="BtnWinClose" Uid="close" Tag="&#xE8BB;" Style="{StaticResource BtnCaption}"/>
    </StackPanel>

    <!-- Foto des alten Themes waehrend eines Theme-Wechsels (siehe New-ThemeReveal) -->
    <Image x:Name="ThemeFx" Grid.ColumnSpan="2" Visibility="Collapsed" IsHitTestVisible="False" Stretch="Fill"/>
  </Grid>
</Window>
'@

