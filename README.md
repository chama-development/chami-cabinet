# ChaMi — кабинет и админка

Личный кабинет в браузере и админка для Telegram-бота [RemnaShop](https://remnashop.mintlify.app/).
Это форк проекта [Vela](https://github.com/velamaker/remnashop-cabinet) с доработками ChaMi.
Ставится поверх работающего бота и не меняет его файлы и данные.

## Как устроено у нас

- **Сервер бота** — бот RemnaShop, панель Remnawave и надстройка (overlay) с API кабинета и админки.
- **Сервер кабинета** — сайт кабинета, ходит в API бота по HTTPS.

Все команды ниже берут код из этого репозитория (`chama-development/chami-cabinet`).

## Сервер кабинета

Установка и обновление — одна и та же команда:

```bash
curl -fsSL https://raw.githubusercontent.com/chama-development/chami-cabinet/main/site-install.sh | sudo bash
```

Код ложится в `/opt/remnashop-cabinet`, настройки (`.env`) сохраняются, уже заданные
значения заново не спрашиваются. После обновления откройте кабинет с обновлением без кэша
(Ctrl+Shift+R) или перезапустите Mini App.

## Сервер бота

Первая установка надстройки (кабинет при этом на отдельном сервере):

```bash
curl -fsSL https://raw.githubusercontent.com/chama-development/chami-cabinet/main/bot-install.sh | sudo bash -s -- api
```

Обновление — из папки бота:

```bash
cd /opt/remnashop && ./update.sh
```

`update.sh` сам делает резервную копию базы, пересобирает надстройку и проверяет, что
все правки бота встали.

**Переход с оригинала Vela (один раз).** Если сервер раньше обновлялся из
`velamaker/remnashop-cabinet`, на нём лежит старый `update.sh`, который смотрит туда же.
Первый раз запустите его с адресом форка — дальше хватит обычного `./update.sh`:

```bash
cd /opt/remnashop && REPO_SLUG=chama-development/chami-cabinet ./update.sh
```

## Разработка

- `cabinet/` — кабинет и админка (React + Vite). Проверки: `npm run lint`, `npm run build`, `npm test`.
- `admin_src/` — надстройка над ботом: API, фоновые задачи, миграции, правки поведения бота
  (`overlay_patches/`). Тесты — `admin_src/tests`, гоняются внутри образа бота (см. `.github/workflows/ci.yml`).
- `adapter/` — переводчик запросов кабинета для бота Bedolaga (у нас не используется).

Изменения идут через pull request в `main`; CI прогоняет сборку и тесты.

### Версии

Номер версии — в файле `VERSION`, описание изменений — в `CHANGELOG.md`. Когда `VERSION`
меняется в `main`, GitHub Actions сам ставит тег `vX.Y.Z`, и админка на серверах
показывает уведомление о новой версии.

### Исправления из оригинала

У форка общая история с Vela, поэтому новые версии оригинала подтягиваются слиянием:

```bash
git remote add upstream https://github.com/velamaker/remnashop-cabinet   # один раз
git fetch upstream
git checkout -b sync-upstream origin/main
git merge upstream/main          # конфликты — там, где мы меняли те же места
```

Затем pull request в `main`. Наши правки при слиянии не теряются: конфликтующие места
разбираются вручную.

## ❤️ Поддержать проект Vela (USDT)

Кабинет основан на открытом проекте Vela. Эти адреса — его автора, не ChaMi.
Отправляйте строго в указанной сети, иначе средства можно потерять.

| Сеть | Адрес |
|------|-------|
| **TON** | `UQDg8ZMFH_ei_Dr42Qrrh20mYruaU6wOvfjl34ArjWwN9lpr` |
| **Tron (TRC20)** | `TCEDU7h8MQ4a16R2WD26ne7wFBmV2pXPse` |
| **Ethereum (ERC20)** | `0x1d28281644140CA0ef0309757cE247430ed9B6A7` |
| **Solana (SOL)** | `BnJAvjJNXcDGozYbu29vmCzvWrFMpgvXEmgKRxCV3SMG` |
