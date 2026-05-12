# Lokalna weryfikacja aplikacji

Ten dokument jest dla testera, ktory chce lokalnie sprawdzic aktualny stan aplikacji bez zgadywania workflow.

## Co da sie sprawdzic teraz

Aktualny stan pozwala zweryfikowac:

- walidacje konfiguracji
- tryb jednorazowy `run-once`
- tryb ciagly `watch`
- integracje `watch` z `Sidekiq` i `Redis`
- zapis wyniku do `results`
- zapis audytu do pliku JSON Lines
- lifecycle pliku `inbox -> processing -> done` albo `invalid`
- recovery `processing -> inbox`

Poza zakresem obecnej weryfikacji sa:

- realna integracja z P1
- realne wywolania `signature-service`

## Wymagania

- Ruby `3.4.9`
- Bundler
- Docker
- `docker compose`

## 1. Przygotowanie projektu

W katalogu repo:

```bash
bundle install
cp config/config.example.yml config/config.yml
cp .env.example .env
```

## 2. Przygotowanie lokalnej konfiguracji dla Ruby

Domyslny `config/config.example.yml` jest przygotowany pod lokalne uruchomienie Ruby.
Najwygodniej zostawic `config/config.yml` bez zmian i ustawic katalogi przez `.env`.

Przyklad wpisow do `.env`:

```dotenv
P1_DATA_ROOT=./tmp/tester/data
P1_LOGS_ROOT=./tmp/tester/logs
P1_CERTIFICATES_BASE_PATH=./tmp/tester/certs
REDIS_URL=redis://127.0.0.1:6379/0
SIGNATURE_SERVICE_URL=http://127.0.0.1:9093
SIGNATURE_TOOL_SIGNING_CERTIFICATE_PATH=/certs/wss.p12
SIGNATURE_TOOL_SIGNING_PASSWORD=...
```

Ten model daje domyslnie:

- `inbox`: `./tmp/tester/data/inbox`
- `processing`: `./tmp/tester/data/processing`
- `done`: `./tmp/tester/data/done`
- `invalid`: `./tmp/tester/data/invalid`
- `results`: `./tmp/tester/data/results`
- `audit_log`: `./tmp/tester/logs/audit.jsonl`

Jesli tester chce pelnej kontroli, moze nadpisac konkretna sciezke pojedynczym wpisem, np. `P1_AUDIT_LOG_PATH=/sciezka/do/innego/audit.jsonl`.

Aplikacja sama tworzy katalogi robocze `inbox`, `processing`, `done`, `invalid`, `results` oraz katalog nadrzedny dla `audit_log`, wiec tester nie musi ich przygotowywac recznie.

Uwaga: obecna walidacja konfiguracji nie sprawdza jeszcze realnej obecnosci plikow certyfikatow, wiec do tej weryfikacji wystarcza placeholdery w YAML.

## 3. Sprawdzenie konfiguracji

```bash
bin/p1-tool verify --config config/config.yml
```

Oczekiwany efekt:

- kod wyjscia `0`
- komunikat `Configuration OK`

## 4. Weryfikacja `run-once`

Uruchom:

```bash
bin/p1-tool run-once \
  --config config/config.yml \
  --input spec/fixtures/runtime/register_encounter_input.json \
  --output tmp/tester/manual-output.json
```

Oczekiwany efekt:

- komunikat `Execution finished with success`
- plik `tmp/tester/manual-output.json`
- wpisy audytu w `tmp/tester/logs/audit.jsonl`

Sprawdz:

```bash
cat tmp/tester/manual-output.json
cat tmp/tester/logs/audit.jsonl
```

W wyniku powinny byc m.in.:

- `result_kind: success`
- `operation_kind: register_encounter`
- `attempt: 1`

## 5. Start Redisa z Docker Compose

Tryb `watch` i test integracyjny zakladaja Redisa uruchomionego przez compose z repo.

Start:

```bash
docker compose -f docker-compose.dev.yml up -d redis
```

Szybka kontrola:

```bash
docker compose -f docker-compose.dev.yml ps
```

Oczekiwany efekt:

- usluga `redis` jest `running`

## 6. Weryfikacja trybu `watch`

W jednym terminalu uruchom:

```bash
bin/p1-tool watch \
  --config config/config.yml \
  --sidekiq-config config/sidekiq.yml \
  --sidekiq-cron-config config/sidekiq-cron.yml
```

Oczekiwany efekt po starcie:

- komunikat `Continuous mode started`
- komunikat z Redis URL

W drugim terminalu wrzuc plik do `inbox`:

```bash
cp spec/fixtures/runtime/register_encounter_input.json tmp/tester/data/inbox/task-1.json
```

Po kilkunastu sekundach sprawdz:

```bash
find tmp/tester -maxdepth 4 -type f | sort
cat tmp/tester/data/results/task-1.json.result.json
cat tmp/tester/logs/audit.jsonl
```

Oczekiwany efekt:

- plik znika z `inbox`
- plik pojawia sie w `done/task-1.json`
- wynik pojawia sie w `results/task-1.json.result.json`
- wynik ma `result_kind: success`
- audit ma zdarzenia `execution_started` i `execution_finished`

## 7. Weryfikacja scenariusza `invalid`

W czasie dzialajacego `watch`:

```bash
cp spec/fixtures/runtime/invalid_input_missing_operation_kind.json tmp/tester/data/inbox/task-invalid.json
```

Po chwili sprawdz:

```bash
find tmp/tester -maxdepth 4 -type f | sort
cat tmp/tester/data/results/task-invalid.json.result.json
```

Oczekiwany efekt:

- plik trafia do `invalid/task-invalid.json`
- wynik ma `result_kind: invalid`
- w `error.code` jest `invalid_input`

## 8. Weryfikacja recovery

Przygotuj plik zalegajacy w `processing`:

```bash
mkdir -p tmp/tester/data/processing
cp spec/fixtures/runtime/register_encounter_input.json tmp/tester/data/processing/task-recover.json
```

Uruchom recovery:

```bash
bin/p1-tool recover --config config/config.yml
```

Po chwili sprawdz:

```bash
find tmp/tester -maxdepth 4 -type f | sort
```

Oczekiwany efekt:

- komunikat `Recovery finished`
- komunikat `Recovered files: 1`
- plik znika z `processing`
- plik pojawia sie w `inbox/task-recover.json`

## 9. Weryfikacja testow automatycznych

Same testy jednostkowe:

```bash
bundle exec rake test:unit
```

Test integracyjny z prawdziwym Redisem:

```bash
bundle exec rake test:integration
```

Pelny zestaw:

```bash
bundle exec rake test
```

Wazne:

- `test:integration` nie podnosi Redisa samodzielnie
- przed nim Redis ma juz dzialac z `docker compose -f docker-compose.dev.yml up -d redis`

## 10. Sprzatanie

Zatrzymanie Redisa:

```bash
docker compose -f docker-compose.dev.yml down
```

Wyczyszczenie lokalnych artefaktow testera:

```bash
rm -rf tmp/tester
```

## Minimalna lista kontrolna

Jesli tester ma malo czasu, wystarczy przejsc ten skrot:

1. `bin/p1-tool verify --config config/config.yml`
2. `bin/p1-tool run-once ...`
3. `docker compose -f docker-compose.dev.yml up -d redis`
4. `bin/p1-tool watch ...`
5. wrzucic `register_encounter_input.json` do `tmp/tester/data/inbox`
6. potwierdzic wynik w `results` i plik w `done`
7. `bin/p1-tool recover --config config/config.yml`
8. `bundle exec rake test:unit`
