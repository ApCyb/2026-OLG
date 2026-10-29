# Обновление ApCyb/olg-chaos-experiments

Релиз: 26 октября 2026 года. Репозиторий: https://github.com/ApCyb/olg-chaos-experiments.

При подготовке инструкции подключение GitHub вернуло 404, поэтому текущая удалённая ветка и дерево файлов не подтверждены. Команды ниже используют `origin/HEAD` вместо предположения о названии основной ветки. Доступ к приватному репозиторию должен быть настроен в вашем Git; HTTPS- или SSH-адрес возьмите из кнопки **Code** в своём аккаунте. Порядок clone/fetch описан в [GitHub Docs](https://docs.github.com/en/get-started/using-git/getting-changes-from-a-remote-repository).

## 1. Подготовить локальный клон

Распакуйте `OLG_EXPERIMENTS_FEX18593_GITHUB_2026-10-26.zip`. Внутри находится папка `olg_experiments_fex18593` с файлами кода, README и `+olg`.

Если клона ещё нет, выполните в Terminal:

```bash
cd "/Users/tmokaev/Documents/ChatGPT/2026-ND-chaos-in-economics-reviews"
git clone https://github.com/ApCyb/olg-chaos-experiments.git
cd olg-chaos-experiments
```

Если клон уже есть, перейдите в него. Проверьте рабочие изменения и адрес:

```bash
git status --short
git remote -v
```

Продолжайте с чистым рабочим деревом; имеющиеся изменения сначала сохраните своим коммитом. Затем получите состояние репозитория и создайте ветку обновления:

```bash
git fetch origin
git remote set-head origin --auto
git switch --create update-q-modes-2026-10-26 origin/HEAD
```

Если такая ветка уже существует, перейдите в неё командой `git switch update-q-modes-2026-10-26`, предварительно просмотрев её состояние.

## 2. Перенести файлы

Проверьте расположение нынешнего кода:

```bash
git ls-tree --name-only HEAD
```

Если `olg_config.m`, `run_olg_experiment.m`, `+olg` и README находятся в корне репозитория, из этого корня выполните:

```bash
rsync -av \
  --exclude='results/' \
  --exclude='.git/' \
  --exclude='*.mex*' \
  --exclude='.gitignore' \
  "../olg_experiments_fex18593/" ./
```

Если архив распакован в другом месте, замените путь источника. Если прежний код находится во вложенной папке, укажите эту папку как назначение и запускайте MATLAB из неё. Завершающий `/` у источника означает копирование **содержимого** папки; не создавайте лишний уровень вложенности поверх текущего кода.

Команда не использует `--delete`, поэтому не удаляет ваши дополнительные файлы, `.github`, `LICENSE` или `CITATION.cff`. Примеры `example_results` включаются в обновление; локальные тяжёлые `results` — нет.

Сохраните имеющийся `.gitignore` и добавьте отсутствующие строки:

```gitignore
results/
*.mex*
*.asv
*.m~
.DS_Store
matlab_crash_dump*
java.log*
slprj/
```

Скомпилированные MEX не публикуются в этом исходном пакете: в репозитории должны быть C++-исходники и `build_olg_fast.m`. Не удаляйте лицензии из `vendor/fex18593` и `vendor/rosenstein`. Если в вашем репозитории уже выбрана лицензия собственного кода, сохраните её.

## 3. Проверить в MATLAB

Завершите прежние вычисления. Откройте обновлённый корень кода как текущую папку MATLAB. Закройте прежний pool и пересоберите ядра: у интегратора изменился ABI. Проверка лицензии в примере позволяет выполнить его и без Parallel Computing Toolbox.

```matlab
if license('test','Distrib_Computing_Toolbox')
    p = gcp('nocreate'); if ~isempty(p), delete(p); end
end
clear functions
clear mex
addpath(pwd, '-begin');
which olg_config -all
build_olg_fast
results = run_tests;
addpath(fullfile(pwd,'tests'));
verify_release;
```

`verify_release` запускает оба профиля индикаторов, контрольные поиски и карты на 308 узлах с двумя workers. Он не запускает плотную сетку Q. При отсутствии компилятора `run_tests` выполняет MATLAB-проверки; native-проверки будут отмечены как пропущенные. `verify_release` требует собранные ядра.

Для своих новых расчётов создайте конфигурацию заново. Схема 4 несовместима с checkpoint от 24 октября и самостоятельных FAST/STAGED/Q_MODES. Проверьте два независимых выбора: третий аргумент `olg_config(...,'first_hit'/'full')` задаёт обработку Q, а `cfg.search.gridMode='estimate'/'full_scan'` — оценку затрат либо реальный восходящий поиск b_L. Для каждого режима/порядка/seed/размера порций используйте свой каталог.

В `full` записываются все узлы: около 12,83 ГБ до сжатия на одно плотное Q. Не добавляйте рабочие batch-карты и checkpoint в Git. Малые примеры внутри `example_results/release_20261026` включаются намеренно. Только читать старые карты можно через `olg_plot_phase_map`; продолжать старый расчёт новым протоколом нельзя.

## 4. Просмотреть и закоммитить

В Terminal, в корне репозитория:

```bash
git status --short
git diff --stat
git diff -- README.md README_RU.md olg_config.m
git diff --check
```

Убедитесь, что новые документы и таблицы различают измеренный DE, оценку стоимости сетки и реальные контрольные запуски. Полный dense-Q опыт не должен описываться как выполненный. Перечень добавляемых файлов проверьте после индексирования:

```bash
git add -A
git diff --cached --stat
git diff --cached --check
git diff --cached --name-only
```

В списке не должно быть `results/`, `*.mex*`, временных файлов или ваших частных данных. `.gitignore` не скрывает уже отслеживаемые файлы; если такие результаты ранее были включены, сначала проверьте их отдельно. После просмотра сделайте коммит:

```bash
git commit -m "Add Q scan modes, shuffle traversal and saved outcome maps"
git push -u origin update-q-modes-2026-10-26
```

## 5. Создать Pull Request

Откройте репозиторий на GitHub и создайте Pull Request из `update-q-modes-2026-10-26` в текущую основную ветку. Возможное название:

> Add first-hit/full Q modes and outcome maps

В описание включите:

- режимы Q `first_hit`/`full`, Feistel shuffle и малые начальные порции;
- полные записи исходов, численные номера регулярных режимов и чтение карты без траекторий;
- отдельное время первого кандидата и завершения полной карты;
- сохранённые исходники FEX DE, кэш и возобновление;
- два варианта сравнения: оценка стоимости сетки и реальный восходящий поиск;
- диагностики SALI/ConDN после подтверждения; только Розенштейн в критерии и timing-базовых линиях;
- новые RU/EN инструкции, происхождение таблиц и результаты локальной проверки;
- отсутствие полноразмерного dense-Q запуска в проверке релиза.

После проверки различий и локальных тестов объедините PR обычным способом. Для отдельного релиза можно создать тег `v2026.10.26` и приложить архив с его SHA-256. Сам ZIP не нужно добавлять в дерево исходников: его место — в assets релиза.

[GitHub: adding files and pushing changes](https://docs.github.com/en/repositories/working-with-files/managing-files/adding-a-file-to-a-repository).
