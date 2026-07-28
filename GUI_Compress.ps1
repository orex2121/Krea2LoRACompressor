param(
    [switch]$ValidateOnly,
    [string]$TestInputFile = "",
    [ValidateSet(5, 25, 50, 75, 95)]
    [int]$TestPercentage = 50
)

# Windows PowerShell 5.1 reads this multilingual file correctly when it is
# saved as UTF-8 with BOM. The project test verifies that encoding.
Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$levels = @(
    [pscustomobject]@{ Percent = 5;   FileLabel = "near_original";  TextKey = "L5" },
    [pscustomobject]@{ Percent = 25;  FileLabel = "high_quality";   TextKey = "L25" },
    [pscustomobject]@{ Percent = 50;  FileLabel = "balanced";       TextKey = "L50" },
    [pscustomobject]@{ Percent = 75;  FileLabel = "compact";        TextKey = "L75" },
    [pscustomobject]@{ Percent = 95;  FileLabel = "maximum_compression"; TextKey = "L95" }
)

$translations = [ordered]@{
    en = @{
        Name="English"; Title="Krea2 LoRA Compressor"; File="LoRA model file"; Browse="Browse...";
        Level="Compression level"; Output="Output version"; Compress="Compress model"; Status="Status";
        Ready="Ready. Select a Krea2 LoRA file."; Running="Compressing. Please wait...";
        Success="Compression completed successfully."; NotFound="Select an existing .safetensors file.";
        OutputExists="The output version already exists. Choose another level or rename/remove that version.";
        BusyClose="Compression is still running. Wait for it to finish before closing the window.";
        Error="Error";
        L5="Minimal 5% — near-original quality, small size gain";
        L25="Light 25% — high quality, noticeable size reduction";
        L50="Balanced 50% — good compromise between size and quality";
        L75="Strong 75% — compact file, visible quality risk";
        L95="Maximum 95% — maximum compression, highest quality risk"
    }
    ru = @{
        Name="Русский"; Title="Компрессор Krea2 LoRA"; File="Файл модели LoRA"; Browse="Обзор...";
        Level="Уровень сжатия"; Output="Выходная версия"; Compress="Сжать модель"; Status="Состояние";
        Ready="Готово. Выберите файл Krea2 LoRA."; Running="Идёт сжатие. Пожалуйста, подождите...";
        Success="Сжатие успешно завершено."; NotFound="Выберите существующий файл .safetensors.";
        OutputExists="Такая выходная версия уже существует. Выберите другой уровень либо переименуйте или удалите эту версию.";
        BusyClose="Сжатие ещё выполняется. Дождитесь завершения перед закрытием окна.";
        Error="Ошибка";
        L5="Минимальное 5% — почти исходное качество, небольшой выигрыш в размере";
        L25="Лёгкое 25% — высокое качество, заметное уменьшение размера";
        L50="Сбалансированное 50% — хороший компромисс размера и качества";
        L75="Сильное 75% — компактный файл, заметный риск потери качества";
        L95="Максимальное 95% — предельное сжатие, наибольший риск потери качества"
    }
    es = @{
        Name="Español"; Title="Compresor Krea2 LoRA"; File="Archivo de modelo LoRA"; Browse="Examinar...";
        Level="Nivel de compresión"; Output="Versión de salida"; Compress="Comprimir modelo"; Status="Estado";
        Ready="Listo. Seleccione un archivo Krea2 LoRA."; Running="Comprimiendo. Espere...";
        Success="Compresión completada correctamente."; NotFound="Seleccione un archivo .safetensors existente.";
        OutputExists="La versión de salida ya existe. Elija otro nivel o cambie/elimine esa versión.";
        BusyClose="La compresión sigue en curso. Espere antes de cerrar."; Error="Error";
        L5="Mínimo 5% — calidad casi original, pequeña reducción";
        L25="Ligero 25% — alta calidad, reducción apreciable";
        L50="Equilibrado 50% — buen compromiso entre tamaño y calidad";
        L75="Fuerte 75% — archivo compacto, riesgo visible de calidad";
        L95="Máximo 95% — compresión máxima, mayor riesgo de calidad"
    }
    fr = @{
        Name="Français"; Title="Compresseur Krea2 LoRA"; File="Fichier du modèle LoRA"; Browse="Parcourir...";
        Level="Niveau de compression"; Output="Version de sortie"; Compress="Compresser le modèle"; Status="État";
        Ready="Prêt. Sélectionnez un fichier Krea2 LoRA."; Running="Compression en cours. Patientez...";
        Success="Compression terminée avec succès."; NotFound="Sélectionnez un fichier .safetensors existant.";
        OutputExists="La version de sortie existe déjà. Choisissez un autre niveau ou renommez/supprimez cette version.";
        BusyClose="La compression est toujours en cours. Attendez avant de fermer."; Error="Erreur";
        L5="Minimal 5% — qualité quasi originale, faible gain de taille";
        L25="Léger 25% — haute qualité, réduction notable";
        L50="Équilibré 50% — bon compromis taille/qualité";
        L75="Fort 75% — fichier compact, risque visible pour la qualité";
        L95="Maximum 95% — compression maximale, risque maximal"
    }
    de = @{
        Name="Deutsch"; Title="Krea2 LoRA Kompressor"; File="LoRA-Modelldatei"; Browse="Durchsuchen...";
        Level="Kompressionsstufe"; Output="Ausgabeversion"; Compress="Modell komprimieren"; Status="Status";
        Ready="Bereit. Eine Krea2-LoRA-Datei auswählen."; Running="Komprimierung läuft. Bitte warten...";
        Success="Komprimierung erfolgreich abgeschlossen."; NotFound="Eine vorhandene .safetensors-Datei auswählen.";
        OutputExists="Die Ausgabeversion existiert bereits. Andere Stufe wählen oder Version umbenennen/löschen.";
        BusyClose="Die Komprimierung läuft noch. Vor dem Schließen warten."; Error="Fehler";
        L5="Minimal 5% — nahezu Originalqualität, geringe Einsparung";
        L25="Leicht 25% — hohe Qualität, merklich kleinere Datei";
        L50="Ausgewogen 50% — guter Kompromiss aus Größe und Qualität";
        L75="Stark 75% — kompakte Datei, sichtbares Qualitätsrisiko";
        L95="Maximum 95% — maximale Kompression, höchstes Qualitätsrisiko"
    }
    pt = @{
        Name="Português"; Title="Compressor Krea2 LoRA"; File="Arquivo do modelo LoRA"; Browse="Procurar...";
        Level="Nível de compressão"; Output="Versão de saída"; Compress="Comprimir modelo"; Status="Estado";
        Ready="Pronto. Selecione um arquivo Krea2 LoRA."; Running="Comprimindo. Aguarde...";
        Success="Compressão concluída com sucesso."; NotFound="Selecione um arquivo .safetensors existente.";
        OutputExists="A versão de saída já existe. Escolha outro nível ou renomeie/exclua essa versão.";
        BusyClose="A compressão ainda está em andamento. Aguarde antes de fechar."; Error="Erro";
        L5="Mínimo 5% — qualidade quase original, pequeno ganho";
        L25="Leve 25% — alta qualidade, redução perceptível";
        L50="Equilibrado 50% — bom compromisso entre tamanho e qualidade";
        L75="Forte 75% — arquivo compacto, risco visível de qualidade";
        L95="Máximo 95% — compressão máxima, maior risco de qualidade"
    }
    zh = @{
        Name="中文"; Title="Krea2 LoRA 压缩器"; File="LoRA 模型文件"; Browse="浏览...";
        Level="压缩级别"; Output="输出版本"; Compress="压缩模型"; Status="状态";
        Ready="就绪。请选择 Krea2 LoRA 文件。"; Running="正在压缩，请稍候...";
        Success="压缩成功完成。"; NotFound="请选择现有的 .safetensors 文件。";
        OutputExists="输出版本已存在。请选择其他级别，或重命名/删除该版本。";
        BusyClose="压缩仍在运行，请等待完成后再关闭。"; Error="错误";
        L5="最低 5% — 接近原始质量，体积略有减小";
        L25="轻度 25% — 高质量，体积明显减小";
        L50="平衡 50% — 体积与质量的良好折中";
        L75="强力 75% — 文件紧凑，有明显质量风险";
        L95="最大 95% — 最高压缩，质量风险最高"
    }
    ja = @{
        Name="日本語"; Title="Krea2 LoRA コンプレッサー"; File="LoRAモデルファイル"; Browse="参照...";
        Level="圧縮レベル"; Output="出力バージョン"; Compress="モデルを圧縮"; Status="状態";
        Ready="準備完了。Krea2 LoRAファイルを選択してください。"; Running="圧縮中です。お待ちください...";
        Success="圧縮が正常に完了しました。"; NotFound="存在する .safetensors ファイルを選択してください。";
        OutputExists="出力バージョンは既に存在します。別のレベルを選ぶか、名前変更または削除してください。";
        BusyClose="圧縮を実行中です。完了するまで閉じないでください。"; Error="エラー";
        L5="最小 5% — ほぼ元の品質、小さなサイズ削減";
        L25="軽量 25% — 高品質、目立つサイズ削減";
        L50="バランス 50% — サイズと品質の良い妥協";
        L75="強力 75% — コンパクト、品質低下のリスクあり";
        L95="最大 95% — 最大圧縮、品質リスク最大"
    }
    ko = @{
        Name="한국어"; Title="Krea2 LoRA 압축기"; File="LoRA 모델 파일"; Browse="찾아보기...";
        Level="압축 수준"; Output="출력 버전"; Compress="모델 압축"; Status="상태";
        Ready="준비됨. Krea2 LoRA 파일을 선택하세요."; Running="압축 중입니다. 기다려 주세요...";
        Success="압축이 성공적으로 완료되었습니다."; NotFound="존재하는 .safetensors 파일을 선택하세요.";
        OutputExists="출력 버전이 이미 있습니다. 다른 수준을 선택하거나 버전을 이름 변경/삭제하세요.";
        BusyClose="압축이 실행 중입니다. 완료될 때까지 기다려 주세요."; Error="오류";
        L5="최소 5% — 원본에 가까운 품질, 작은 크기 감소";
        L25="가벼움 25% — 높은 품질, 눈에 띄는 크기 감소";
        L50="균형 50% — 크기와 품질의 좋은 절충";
        L75="강함 75% — 작은 파일, 눈에 띄는 품질 위험";
        L95="최대 95% — 최대 압축, 가장 높은 품질 위험"
    }
    ar = @{
        Name="العربية"; Title="ضاغط Krea2 LoRA"; File="ملف نموذج LoRA"; Browse="استعراض...";
        Level="مستوى الضغط"; Output="نسخة الإخراج"; Compress="ضغط النموذج"; Status="الحالة";
        Ready="جاهز. اختر ملف Krea2 LoRA."; Running="جارٍ الضغط. يرجى الانتظار...";
        Success="اكتمل الضغط بنجاح."; NotFound="اختر ملف .safetensors موجوداً.";
        OutputExists="نسخة الإخراج موجودة بالفعل. اختر مستوى آخر أو أعد تسمية/احذف النسخة.";
        BusyClose="لا يزال الضغط قيد التشغيل. انتظر قبل إغلاق النافذة."; Error="خطأ";
        L5="أدنى 5% — جودة قريبة من الأصل وتقليل بسيط";
        L25="خفيف 25% — جودة عالية وتقليل ملحوظ";
        L50="متوازن 50% — توازن جيد بين الحجم والجودة";
        L75="قوي 75% — ملف مضغوط مع خطر ملحوظ على الجودة";
        L95="أقصى 95% — أقصى ضغط وأعلى خطر على الجودة"
    }
    hi = @{
        Name="हिन्दी"; Title="Krea2 LoRA कंप्रेसर"; File="LoRA मॉडल फ़ाइल"; Browse="ब्राउज़...";
        Level="कंप्रेशन स्तर"; Output="आउटपुट संस्करण"; Compress="मॉडल कंप्रेस करें"; Status="स्थिति";
        Ready="तैयार। Krea2 LoRA फ़ाइल चुनें।"; Running="कंप्रेस हो रहा है। कृपया प्रतीक्षा करें...";
        Success="कंप्रेशन सफलतापूर्वक पूरा हुआ।"; NotFound="मौजूदा .safetensors फ़ाइल चुनें।";
        OutputExists="आउटपुट संस्करण पहले से मौजूद है। दूसरा स्तर चुनें या संस्करण का नाम बदलें/हटाएँ।";
        BusyClose="कंप्रेशन चल रहा है। विंडो बंद करने से पहले प्रतीक्षा करें।"; Error="त्रुटि";
        L5="न्यूनतम 5% — लगभग मूल गुणवत्ता, छोटा आकार लाभ";
        L25="हल्का 25% — उच्च गुणवत्ता, स्पष्ट आकार कमी";
        L50="संतुलित 50% — आकार और गुणवत्ता का अच्छा संतुलन";
        L75="मजबूत 75% — छोटा फ़ाइल, गुणवत्ता का स्पष्ट जोखिम";
        L95="अधिकतम 95% — अधिकतम कंप्रेशन, सबसे अधिक गुणवत्ता जोखिम"
    }
    it = @{
        Name="Italiano"; Title="Compressore Krea2 LoRA"; File="File modello LoRA"; Browse="Sfoglia...";
        Level="Livello di compressione"; Output="Versione di uscita"; Compress="Comprimi modello"; Status="Stato";
        Ready="Pronto. Seleziona un file Krea2 LoRA."; Running="Compressione in corso. Attendere...";
        Success="Compressione completata con successo."; NotFound="Seleziona un file .safetensors esistente.";
        OutputExists="La versione di uscita esiste già. Scegli un altro livello o rinomina/elimina la versione.";
        BusyClose="La compressione è ancora in corso. Attendi prima di chiudere."; Error="Errore";
        L5="Minimo 5% — qualità quasi originale, piccolo risparmio";
        L25="Leggero 25% — alta qualità, riduzione evidente";
        L50="Bilanciato 50% — buon compromesso tra dimensione e qualità";
        L75="Forte 75% — file compatto, rischio visibile per la qualità";
        L95="Massimo 95% — compressione massima, massimo rischio di qualità"
    }
}

$requiredLanguageKeys = @("Name", "Title", "File", "Browse", "Level", "Output", "Compress", "Status", "Ready", "Running", "Success", "NotFound", "OutputExists", "BusyClose", "Error", "L5", "L25", "L50", "L75", "L95")
if ($translations.Count -ne 12) { throw "Expected 12 languages, found $($translations.Count)." }
if ($levels.Count -ne 5) { throw "Expected 5 compression levels, found $($levels.Count)." }
foreach ($code in $translations.Keys) {
    foreach ($key in $requiredLanguageKeys) {
        if (-not $translations[$code].ContainsKey($key)) {
            throw "Translation '$code' is missing '$key'."
        }
    }
}
if (($levels.Percent -join ",") -ne "5,25,50,75,95") {
    throw "Unexpected compression levels."
}

$pythonScript = Join-Path $PSScriptRoot "batch_strip_krea2.py"
if (-not (Test-Path -LiteralPath $pythonScript -PathType Leaf)) {
    throw "batch_strip_krea2.py was not found beside the GUI script."
}

if ($ValidateOnly) {
    Write-Output "GUI_VALIDATION_OK languages=12 levels=5"
    return
}

$script:languageCode = "en"
$script:process = $null
$script:isRunning = $false
$script:testResult = $null

$form = New-Object System.Windows.Forms.Form
$form.Text = $translations.en.Title
$form.ClientSize = New-Object System.Drawing.Size(720, 520)
$form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
$form.MaximizeBox = $false
$form.MinimizeBox = $true
$form.BackColor = [System.Drawing.Color]::FromArgb(35, 37, 41)
$form.ForeColor = [System.Drawing.Color]::Gainsboro
$form.Font = New-Object System.Drawing.Font("Segoe UI", 9)

$iconPath = Join-Path $PSScriptRoot "krea2_compressor.ico"
if (Test-Path -LiteralPath $iconPath -PathType Leaf) {
    try { $form.Icon = New-Object System.Drawing.Icon($iconPath) } catch { }
}

$labelColor = [System.Drawing.Color]::FromArgb(220, 220, 220)
$inputBack = [System.Drawing.Color]::FromArgb(54, 57, 63)
$accent = [System.Drawing.Color]::FromArgb(73, 170, 255)

$languageCombo = New-Object System.Windows.Forms.ComboBox
$languageCombo.Location = New-Object System.Drawing.Point(535, 20)
$languageCombo.Size = New-Object System.Drawing.Size(165, 28)
$languageCombo.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$languageCombo.BackColor = $inputBack
$languageCombo.ForeColor = [System.Drawing.Color]::White
foreach ($code in $translations.Keys) { [void]$languageCombo.Items.Add($translations[$code].Name) }
$languageCombo.SelectedIndex = 0

$fileLabel = New-Object System.Windows.Forms.Label
$fileLabel.Location = New-Object System.Drawing.Point(20, 70)
$fileLabel.Size = New-Object System.Drawing.Size(680, 22)
$fileLabel.ForeColor = $labelColor

$fileText = New-Object System.Windows.Forms.TextBox
$fileText.Location = New-Object System.Drawing.Point(20, 96)
$fileText.Size = New-Object System.Drawing.Size(575, 26)
$fileText.BackColor = $inputBack
$fileText.ForeColor = [System.Drawing.Color]::White
$fileText.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle

$browseButton = New-Object System.Windows.Forms.Button
$browseButton.Location = New-Object System.Drawing.Point(605, 94)
$browseButton.Size = New-Object System.Drawing.Size(95, 30)
$browseButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$browseButton.BackColor = [System.Drawing.Color]::FromArgb(70, 73, 80)
$browseButton.ForeColor = [System.Drawing.Color]::White

$levelLabel = New-Object System.Windows.Forms.Label
$levelLabel.Location = New-Object System.Drawing.Point(20, 145)
$levelLabel.Size = New-Object System.Drawing.Size(680, 22)
$levelLabel.ForeColor = $labelColor

$levelCombo = New-Object System.Windows.Forms.ComboBox
$levelCombo.Location = New-Object System.Drawing.Point(20, 171)
$levelCombo.Size = New-Object System.Drawing.Size(680, 28)
$levelCombo.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$levelCombo.BackColor = $inputBack
$levelCombo.ForeColor = [System.Drawing.Color]::White

$outputLabel = New-Object System.Windows.Forms.Label
$outputLabel.Location = New-Object System.Drawing.Point(20, 222)
$outputLabel.Size = New-Object System.Drawing.Size(680, 22)
$outputLabel.ForeColor = $labelColor

$outputText = New-Object System.Windows.Forms.TextBox
$outputText.Location = New-Object System.Drawing.Point(20, 248)
$outputText.Size = New-Object System.Drawing.Size(680, 26)
$outputText.BackColor = [System.Drawing.Color]::FromArgb(46, 49, 54)
$outputText.ForeColor = [System.Drawing.Color]::Silver
$outputText.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$outputText.ReadOnly = $true

$compressButton = New-Object System.Windows.Forms.Button
$compressButton.Location = New-Object System.Drawing.Point(20, 300)
$compressButton.Size = New-Object System.Drawing.Size(680, 44)
$compressButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$compressButton.BackColor = $accent
$compressButton.ForeColor = [System.Drawing.Color]::Black
$compressButton.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)

$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(20, 361)
$progressBar.Size = New-Object System.Drawing.Size(680, 20)
$progressBar.Style = [System.Windows.Forms.ProgressBarStyle]::Blocks
$progressBar.Minimum = 0
$progressBar.Maximum = 100
$progressBar.Value = 0

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Location = New-Object System.Drawing.Point(20, 397)
$statusLabel.Size = New-Object System.Drawing.Size(680, 22)
$statusLabel.ForeColor = $labelColor

$statusText = New-Object System.Windows.Forms.TextBox
$statusText.Location = New-Object System.Drawing.Point(20, 423)
$statusText.Size = New-Object System.Drawing.Size(680, 76)
$statusText.Multiline = $true
$statusText.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
$statusText.ReadOnly = $true
$statusText.BackColor = [System.Drawing.Color]::FromArgb(27, 29, 32)
$statusText.ForeColor = [System.Drawing.Color]::LightGreen
$statusText.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle

$form.Controls.AddRange(@(
    $languageCombo, $fileLabel, $fileText, $browseButton, $levelLabel,
    $levelCombo, $outputLabel, $outputText, $compressButton, $progressBar,
    $statusLabel, $statusText
))
$form.AcceptButton = $compressButton

function Get-SelectedLevel {
    $index = $levelCombo.SelectedIndex
    if ($index -lt 0 -or $index -ge $levels.Count) { $index = 2 }
    return $levels[$index]
}

function Update-OutputPath {
    $source = $fileText.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($source)) {
        $outputText.Text = ""
        return
    }
    $level = Get-SelectedLevel
    $directory = [System.IO.Path]::GetDirectoryName($source)
    $stem = [System.IO.Path]::GetFileNameWithoutExtension($source)
    $name = "{0}_stripped_{1}pct_{2}.safetensors" -f $stem, $level.Percent, $level.FileLabel
    $outputText.Text = [System.IO.Path]::Combine($directory, $name)
}

function Update-UiText {
    $selectedLevel = $levelCombo.SelectedIndex
    if ($selectedLevel -lt 0) { $selectedLevel = 2 }
    $t = $translations[$script:languageCode]
    $form.Text = $t.Title
    $fileLabel.Text = $t.File
    $browseButton.Text = $t.Browse
    $levelLabel.Text = $t.Level
    $outputLabel.Text = $t.Output
    $compressButton.Text = $t.Compress
    $statusLabel.Text = $t.Status

    $levelCombo.BeginUpdate()
    $levelCombo.Items.Clear()
    foreach ($level in $levels) { [void]$levelCombo.Items.Add($t[$level.TextKey]) }
    $levelCombo.SelectedIndex = $selectedLevel
    $levelCombo.EndUpdate()

    if (-not $script:isRunning) {
        $statusText.Text = $t.Ready
        $statusText.ForeColor = [System.Drawing.Color]::LightGreen
    }
    Update-OutputPath
}

function Set-ControlsEnabled([bool]$enabled) {
    $browseButton.Enabled = $enabled
    $fileText.Enabled = $enabled
    $levelCombo.Enabled = $enabled
    $languageCombo.Enabled = $enabled
    $compressButton.Enabled = $enabled
}

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 250
$timer.Add_Tick({
    if (-not $script:isRunning -or $null -eq $script:process) { return }
    if (-not $script:process.HasExited) { return }

    $timer.Stop()
    $stdout = $script:process.StandardOutput.ReadToEnd().Trim()
    $stderr = $script:process.StandardError.ReadToEnd().Trim()
    $exitCode = $script:process.ExitCode
    $script:process.Dispose()
    $script:process = $null
    $script:isRunning = $false
    Set-ControlsEnabled $true
    $progressBar.Style = [System.Windows.Forms.ProgressBarStyle]::Blocks

    $t = $translations[$script:languageCode]
    if ($exitCode -eq 0 -and (Test-Path -LiteralPath $outputText.Text -PathType Leaf)) {
        $progressBar.Value = 100
        $statusText.ForeColor = [System.Drawing.Color]::LightGreen
        $statusText.Text = $t.Success
        if (-not [string]::IsNullOrWhiteSpace($stdout)) { $statusText.AppendText("`r`n`r`n$stdout") }
        if (-not [string]::IsNullOrWhiteSpace($TestInputFile)) {
            $script:testResult = "GUI_COMPRESSION_OK output=$($outputText.Text)"
            $form.Close()
        }
    } else {
        $progressBar.Value = 0
        $statusText.ForeColor = [System.Drawing.Color]::Salmon
        $details = if (-not [string]::IsNullOrWhiteSpace($stderr)) { $stderr } else { $stdout }
        $statusText.Text = "$($t.Error) (exit $exitCode)"
        if (-not [string]::IsNullOrWhiteSpace($details)) { $statusText.AppendText("`r`n`r`n$details") }
        if (-not [string]::IsNullOrWhiteSpace($TestInputFile)) {
            $script:testResult = "GUI_COMPRESSION_FAIL exit=$exitCode details=$details"
            $form.Close()
        }
    }
})

$browseButton.Add_Click({
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Title = $translations[$script:languageCode].File
    $dialog.Filter = "SafeTensors (*.safetensors)|*.safetensors"
    $dialog.CheckFileExists = $true
    $dialog.Multiselect = $false
    if ($dialog.ShowDialog($form) -eq [System.Windows.Forms.DialogResult]::OK) {
        $fileText.Text = $dialog.FileName
        Update-OutputPath
    }
    $dialog.Dispose()
})

$fileText.Add_TextChanged({ Update-OutputPath })
$levelCombo.Add_SelectedIndexChanged({ Update-OutputPath })
$languageCombo.Add_SelectedIndexChanged({
    $index = $languageCombo.SelectedIndex
    if ($index -ge 0 -and $index -lt $translations.Count) {
        $script:languageCode = @($translations.Keys)[$index]
        Update-UiText
    }
})

$compressButton.Add_Click({
    $t = $translations[$script:languageCode]
    $source = $fileText.Text.Trim()
    Update-OutputPath
    $destination = $outputText.Text.Trim()

    if (-not (Test-Path -LiteralPath $source -PathType Leaf) -or [System.IO.Path]::GetExtension($source).ToLowerInvariant() -ne ".safetensors") {
        $statusText.ForeColor = [System.Drawing.Color]::Salmon
        $statusText.Text = $t.NotFound
        return
    }
    if ([string]::Equals($source, $destination, [System.StringComparison]::OrdinalIgnoreCase)) {
        $statusText.ForeColor = [System.Drawing.Color]::Salmon
        $statusText.Text = "$($t.Error): output path equals input path."
        return
    }
    if (Test-Path -LiteralPath $destination) {
        $statusText.ForeColor = [System.Drawing.Color]::Salmon
        $statusText.Text = $t.OutputExists
        return
    }

    try {
        $python = Get-Command "python.exe" -ErrorAction Stop
        $level = Get-SelectedLevel
        $processInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processInfo.FileName = $python.Source
        $processInfo.WorkingDirectory = $PSScriptRoot
        $processInfo.Arguments = '"{0}" --file "{1}" --percentage {2} --output-name "{3}"' -f $pythonScript, $source, $level.Percent, $destination
        $processInfo.UseShellExecute = $false
        $processInfo.CreateNoWindow = $true
        $processInfo.RedirectStandardOutput = $true
        $processInfo.RedirectStandardError = $true
        $processInfo.StandardOutputEncoding = New-Object System.Text.UTF8Encoding($false)
        $processInfo.StandardErrorEncoding = New-Object System.Text.UTF8Encoding($false)
        $processInfo.EnvironmentVariables["PYTHONUTF8"] = "1"

        $script:process = New-Object System.Diagnostics.Process
        $script:process.StartInfo = $processInfo
        if (-not $script:process.Start()) { throw "Python process did not start." }

        $script:isRunning = $true
        Set-ControlsEnabled $false
        $progressBar.Value = 0
        $progressBar.Style = [System.Windows.Forms.ProgressBarStyle]::Marquee
        $progressBar.MarqueeAnimationSpeed = 30
        $statusText.ForeColor = [System.Drawing.Color]::Khaki
        $statusText.Text = $t.Running
        $timer.Start()
    } catch {
        $script:isRunning = $false
        if ($null -ne $script:process) { $script:process.Dispose(); $script:process = $null }
        Set-ControlsEnabled $true
        $progressBar.Style = [System.Windows.Forms.ProgressBarStyle]::Blocks
        $progressBar.Value = 0
        $statusText.ForeColor = [System.Drawing.Color]::Salmon
        $statusText.Text = "$($t.Error): $($_.Exception.Message)"
        if (-not [string]::IsNullOrWhiteSpace($TestInputFile)) {
            $script:testResult = "GUI_COMPRESSION_FAIL start=$($_.Exception.Message)"
            $form.Close()
        }
    }
})

$form.Add_FormClosing({
    param($sender, $eventArgs)
    if ($script:isRunning) {
        $eventArgs.Cancel = $true
        [System.Windows.Forms.MessageBox]::Show(
            $form,
            $translations[$script:languageCode].BusyClose,
            $translations[$script:languageCode].Title,
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
    }
})

Update-UiText

if (-not [string]::IsNullOrWhiteSpace($TestInputFile)) {
    $form.Add_Shown({
        if (-not (Test-Path -LiteralPath $TestInputFile -PathType Leaf)) {
            $script:testResult = "GUI_COMPRESSION_FAIL missing_test_input=$TestInputFile"
            $form.Close()
            return
        }
        $fileText.Text = (Resolve-Path -LiteralPath $TestInputFile).Path
        for ($index = 0; $index -lt $levels.Count; $index++) {
            if ($levels[$index].Percent -eq $TestPercentage) {
                $levelCombo.SelectedIndex = $index
                break
            }
        }
        $compressButton.PerformClick()
    })
}

[void]$form.ShowDialog()

if (-not [string]::IsNullOrWhiteSpace($TestInputFile)) {
    if ($script:testResult -like "GUI_COMPRESSION_OK*") {
        Write-Output $script:testResult
    } else {
        throw $(if ($script:testResult) { $script:testResult } else { "GUI_COMPRESSION_FAIL no_result" })
    }
}
