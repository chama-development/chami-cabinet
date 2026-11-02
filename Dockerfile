# Базовый образ ЗАПИННЕН на точную версию ради воспроизводимости прод-сборок:
# новый релиз base не «прилетит» на rebuild и не сломает overlay молча.
# Тег базы вынесен в ARG BASE_TAG (дефолт — пин ниже). Обновление базы — осознанно:
#   ./update.sh --base <тег>   (прогонит ./check-update.sh и пересоберёт overlay)
# что выставляет BASE_TAG в .env; Dockerfile/git при этом НЕ меняются.
ARG BASE_TAG=v0.8.2
FROM ghcr.io/snoups/remnashop:${BASE_TAG} AS overlay-build

# Патчи пакетов Alpine базового образа. Пин BASE_TAG выше решает, КАКОЙ базовый образ
# берём; он не должен означать «оставаться с непропатченной ОС». Проверка по базе OSV
# 22 августа 2026 нашла в базе 3.24.1 postgresql18-client/libpq 18.4 с 28 CVE
# (исправлено в 18.6) — а `pg_dump` из этого образа делает бэкапы базы бота.
# Апгрейд идёт списком «всё, для чего есть обновление» намеренно: перечислять пакеты
# руками значит однажды не заметить новую дыру в неперечисленном.
RUN apk update && apk upgrade --no-cache && rm -rf /var/cache/apk/*

# Экспорт в Excel (.xlsx с автофильтром) — лёгкая write-only библиотека.
# ВАЖНО: приложение крутится из venv /opt/remnashop/.venv (uv-managed, без pip),
# поэтому ставим системным pip через --target прямо в site-packages venv
# (XlsxWriter — чистый python, --target безопасен). Отдельным слоем — кэшируется.
RUN pip install --no-cache-dir --target=/opt/remnashop/.venv/lib/python3.12/site-packages XlsxWriter==3.2.0

# Web Push (браузерные push PWA): pywebpush тянет py-vapid + http-ece; cryptography
# уже есть в базе. Тот же приём --target в site-packages venv. Отдельным слоем.
RUN pip install --no-cache-dir --target=/opt/remnashop/.venv/lib/python3.12/site-packages pywebpush==2.3.0

# Security updates are installed in-place in the upstream uv-managed venv.
# Keep the application framework pins; update vulnerable runtime dependencies.
RUN pip install --no-cache-dir --upgrade "pip==26.2.2"
RUN pip --python /opt/remnashop/.venv/bin/python install --no-cache-dir --upgrade \
      "fastapi==0.140.0" \
      "starlette==1.3.1" \
      "python-multipart==0.0.32" \
      "pillow==13.0.0" \
      "orjson==3.11.9" \
      "Mako==1.4.2" \
      "click==8.3.3" \
      "idna==3.18" \
      "python-dotenv==1.2.2" \
      "PyJWT==2.15.1" \
      "certifi==2026.10.23" \
      "anyio==4.14.2" \
      "dnspython==2.9.0" \
      "multidict==6.9.1"

# Upstream aiogram/remnapy still cap these packages below the security fixes.
# Retain the existing, runtime-tested override; install aiohttp's dependencies
# explicitly so --no-deps cannot leave a newly required dependency behind.
RUN pip --python /opt/remnashop/.venv/bin/python install --no-cache-dir --upgrade \
      "yarl==1.25.1" \
      "aiosignal==1.4.0" \
      "aiohappyeyeballs==2.6.1" \
 && pip --python /opt/remnashop/.venv/bin/python install --no-cache-dir --no-deps --upgrade \
      "aiohttp==3.14.4" \
      "cryptography==50.0.0"

# Совместимость с Remnawave 2.8+: панель сменила контракты (hwid userUuid→userId,
# host tag→tags и регистр xHttpExtraParams) → remnapy 2.7.0 роняет ValidationError
# на меню «Устройства» и «Статус сервиса». Патчим модели IN-PLACE в venv (fail-closed:
# если блок не найден — билд падает). Отдельным слоем. Подробности: scripts/patch-remnapy-2.8.py.
COPY scripts/patch-remnapy-2.8.py /opt/remnashop/scripts/patch-remnapy-2.8.py
RUN /opt/remnashop/.venv/bin/python /opt/remnashop/scripts/patch-remnapy-2.8.py

# Переводы бота НЕ правим на диске. Раньше здесь работал скрипт, который менял
# assets.default/translations/ru/*.ftl прямо в образе. Те же исправления теперь
# вносятся в памяти, в момент сборки бандла переводов — см.
# admin_src/overlay_patches/translations_ru.py. Файлы бота остаются базовыми.

# Правки поведения бота, которые НЕ трогают его файлы (см. overlay_patches/__init__.py).
# Подключаются через sitecustomize.py — его импортирует сам интерпретатор, до любого
# кода приложения, поэтому правки видят ВСЕ процессы: бот, веб, taskiq-воркер и
# планировщик (у них разные точки входа, общего места в коде приложения нет).
COPY admin_src/overlay_patches/ /opt/remnashop/overlay_patches/
COPY scripts/sitecustomize.py /opt/remnashop/.venv/lib/python3.12/site-packages/sitecustomize.py

# Overlay admin API files on top of the base image
COPY admin_src/src/ /opt/remnashop/src/

# Инструменты для разбора вручную. Сторож двойников (tasks/account_duplicates.py)
# присылает владельцу ГОТОВУЮ команду на merge-duplicate.py — а её нечем было
# выполнить: папка scripts/ в образ не попадала и никуда не монтируется, то есть
# уведомление предлагало то, чего в системе нет.
COPY scripts/merge-duplicate.py /opt/remnashop/scripts/merge-duplicate.py
COPY scripts/check-panel-compat.py /opt/remnashop/scripts/check-panel-compat.py

# Версия форка (её читает планировщик для уведомлений об обновлении). Это версия,
# на которой собран образ — ровно то, что сейчас работает.
COPY VERSION /opt/remnashop/VERSION

# Курируемый список изменений — его читает лента обновлений в админке.
COPY CHANGELOG.md /opt/remnashop/CHANGELOG.md

# Точку входа НЕ переписываем: `docker-entrypoint.sh` бота остаётся побайтово таким
# же, как в базовом образе. Он зовёт `src.__main__:application`, а эта фабрика сама
# отдаёт кабинет — см. admin_src/overlay_patches/entrypoint.py. Раньше здесь стоял
# sed по строке запуска, то есть сборка меняла файл бота.

# Only application data is writable. Source code and the venv remain root-owned.
RUN addgroup -S -g 10001 remnashop \
 && adduser -S -D -u 10001 -G remnashop -h /home/remnashop remnashop \
 && mkdir -p /opt/remnashop/assets /opt/remnashop/logs /opt/remnashop/backups \
 && chown -R 10001:10001 /opt/remnashop/assets /opt/remnashop/logs /opt/remnashop/backups
ENV HOME=/home/remnashop
ENV PYTHONDONTWRITEBYTECODE=1
COPY scripts/prepare-runtime-dirs.py scripts/container-healthcheck.py /opt/remnashop/scripts/

# CI needs an installer for isolated pytest dependencies, under the same UID as prod.
FROM overlay-build AS test
USER remnashop:remnashop

FROM overlay-build AS runtime
# Remove the installer and its vulnerable private dependency copies from production.
RUN /usr/local/bin/python -m pip uninstall -y pip
USER remnashop:remnashop
HEALTHCHECK --interval=30s --timeout=5s --start-period=120s --retries=3 \
  CMD ["python", "/opt/remnashop/scripts/container-healthcheck.py"]
