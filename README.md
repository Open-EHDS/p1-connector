# p1-connector

Lekki runtime Ruby do integracji plikowej z platforma P1.

## Dla kogo jest ten projekt

To narzedzie jest przygotowywane dla integratora, ktory chce uruchamiac zadania wsadowe przekazywane jako pliki JSON i odbierac wynik w postaci pliku JSON oraz wpisow audytowych.

Na obecnym etapie projekt udostepnia lokalny tryb jednorazowego wykonania `run-once`, tryb ciagly `watch` oparty o `Sidekiq`, `sidekiq-cron` i `Redis`, komende operatorska `recover` oraz pomocnicze narzedzie wdrozeniowe MVP `p1-live-smoke`.

## Co dziala teraz

Aktualnie dostepne sa:

- walidacja konfiguracji z pliku YAML
- wybor srodowiska P1: `integration` (`isus.ezdrowie.gov.pl`) albo `production` (`sus.ezdrowie.gov.pl`)
- komunikacja z P1 oparta o JWT WSS + mutual TLS
- przetworzenie pojedynczego pliku JSON w trybie `run-once`
- tryb ciagly `watch` z embedded `Sidekiq`
- cykliczne skanowanie `inbox` przez `sidekiq-cron`
- enqueue joba przetwarzajacego po atomowym przejeciu pliku `inbox -> processing`
- minimalna polityka retry dla bledow technicznych: maksymalnie 2 proby lacznie
- walidacja minimalnego kontraktu wejscia
- operacje biznesowe:
  - `register_encounter`
  - `register_procedure`
  - `register_condition`
  - `register_provenance`
  - `get_resource`
  - `destroy_resource`
- realna integracja `register_encounter` z P1:
  - pobranie tokenu
  - wyszukanie pacjenta
  - utworzenie pacjenta, jesli nie istnieje
  - utworzenie albo aktualizacja `Encounter`
- realna integracja `register_procedure`, `register_condition` i `register_provenance` z P1
- realna integracja z `signature-service` dla `register_provenance`
- zapis wyniku do pliku JSON
- zapis audytu technicznego do pliku JSON Lines

## Wymagania

- Ruby `3.4.9`
- Bundler
- Docker i `docker compose` do lokalnego Redisa, trybu `watch` i testu integracyjnego

## Przygotowanie

1. Zainstaluj zaleznosci:

```bash
bundle install
```

2. Przygotuj konfiguracje aplikacji:

```bash
cp config/config.example.yml config/config.yml
```

3. Opcjonalnie przygotuj lokalne zmienne srodowiskowe na podstawie `.env.example`:

```bash
cp .env.example .env
```

Wazne:

- `bin/p1-tool` automatycznie laduje `.env`, jesli plik istnieje
- zanim uruchomisz `verify`, `run-once` albo `watch`, ustaw poprawne `WSS_CERT_PASSWORD` i `TLS_CERT_PASSWORD`
- `recover` nie wymaga hasel do certyfikatow ani dostepu do P1; laduje konfiguracje bez walidacji runtime
- dopasuj `P1_CERTIFICATES_BASE_PATH` do miejsca, w ktorym masz certyfikaty; przykladowy `config/config.example.yml` domyslnie wskazuje `./volumes/certs`

4. Jesli chcesz uruchomic Redisa przez Docker Compose:

```bash
docker compose -f docker-compose.dev.yml up -d redis
```

Plik `.env.example` opisuje lokalny model uruchomienia Ruby. `docker-compose.dev.yml` sluzy do wystawienia lokalnych uslug pomocniczych.

## Konfiguracja

Przykladowa konfiguracja znajduje sie w `config/config.example.yml`.

Konfiguracja obejmuje:

- katalogi robocze: `inbox`, `processing`, `done`, `invalid`, `results`
- sciezke do pliku audytowego `audit_log`
- ustawienia `redis`
- konfiguracje `Sidekiq` w `config/sidekiq.yml`
- harmonogram `sidekiq-cron` w `config/sidekiq-cron.yml`
- adres `signature_service`
- konfiguracje P1 w sekcji `p1`
- dane `subject`
- konfiguracje certyfikatow `wss` i `tls`

Pola wymagane przez schemat konfiguracji:

- `paths.inbox`, `paths.processing`, `paths.done`, `paths.invalid`, `paths.results`, `paths.audit_log`
- `redis.url`
- `signature_service.url`
- `p1.environment`
- `subject.oid`, `subject.identification_code`, `subject.department_code_v`, `subject.department_code_vii`, `subject.is_practice`, `subject.medical_chamber`
- `certificates.base_path`
- `certificates.wss.filename`, `certificates.wss.password_env`
- `certificates.tls.filename`, `certificates.tls.password_env`

Wazne:

- dla trybu `run-once` wynik jest zapisywany pod sciezka przekazana parametrem `--output`
- plik audytowy jest zapisywany pod sciezka `paths.audit_log` z konfiguracji
- katalogi robocze `inbox`, `processing`, `done`, `invalid` i `results` musza znajdowac sie na tym samym filesystemie; runtime przenosi pliki przez atomowe `rename`
- debugowe XML-e moga byc zapisywane po ustawieniu `P1_DEBUG_XML=1`; katalog mozna nadpisac przez `P1_DEBUG_XML_PATH`
- `p1.environment` przelacza host docelowy:
  - `integration` -> `https://isus.ezdrowie.gov.pl`
  - `production` -> `https://sus.ezdrowie.gov.pl`
- konfiguracja jest walidowana semantycznie przy starcie:
  - sprawdzenie wymaganych envow z haslami
  - sprawdzenie odczytu plikow `wss` i `tls`
  - proba otwarcia obu plikow PKCS#12
- katalogi `inbox`, `processing`, `done`, `invalid`, `results` sa juz czescia modelu konfiguracji, ale pelny lifecycle katalogowy bedzie wykorzystywany przez tryb ciagly
- `config/config.example.yml` mozna odpalic lokalnie bez zmian, albo nadpisac katalogi przez `.env`
- najprostszy model to ustawienie `P1_DATA_ROOT`, `P1_LOGS_ROOT` i `P1_CERTIFICATES_BASE_PATH`
- jesli integrator chce pelnej kontroli, moze nadpisac kazda sciezke osobno przez `P1_INBOX_PATH`, `P1_PROCESSING_PATH`, `P1_DONE_PATH`, `P1_INVALID_PATH`, `P1_RESULTS_PATH` i `P1_AUDIT_LOG_PATH`
- hasla do certyfikatow sa czytane z envow wskazanych przez:
  - `certificates.wss.password_env`
  - `certificates.tls.password_env`

## Docker Compose

W repo jest [docker-compose.dev.yml](docker-compose.dev.yml) z usluga pomocnicza do developmentu.

Aktualnie jest tam:

- `redis` - gotowy do uzycia przez `Sidekiq`
- `signature-tool` - lokalny `signature-service` budowany z `services/signature-tool` i wystawiony domyslnie na porcie `9093` hosta (`8080` w kontenerze)

### Redis

Start tylko Redisa:

```bash
docker compose -f docker-compose.dev.yml up -d redis
```

Zatrzymanie:

```bash
docker compose -f docker-compose.dev.yml down
```

Compose jest traktowany jako czesc narzedzia, nie tylko dodatek developerski. Testy integracyjne zakladaja, ze `redis` jest podnoszony z [docker-compose.dev.yml](docker-compose.dev.yml).

W MVP wspierany jest jeden sposob pracy:

1. lokalny Ruby + `redis` uruchomiony z `docker compose`

## Dostepne komendy

Glowne entrypointy repo:

- `bin/p1-tool` - podstawowe CLI runtime
- `bin/p1-live-smoke` - pomocnicze narzedzie wdrozeniowe MVP, poza stalym kontraktem runtime

### Sprawdzenie konfiguracji

```bash
bin/p1-tool verify --config config/config.yml
```

Komenda:

- laduje konfiguracje YAML
- waliduje wymagane pola
- sprawdza wymagane envy z haslami do certyfikatow
- probuje otworzyc oba pliki PKCS#12
- potwierdza gotowosc runtime dla komend korzystajacych z integracji P1
- zwraca kod `0`, jesli konfiguracja jest poprawna

### Przetworzenie jednego pliku

```bash
bin/p1-tool run-once \
  --config config/config.yml \
  --input /sciezka/do/input.json \
  --output /sciezka/do/output.json
```

Komenda:

- wczytuje plik wejsciowy JSON
- waliduje kontrakt wejscia
- wykonuje jedna z obslugiwanych operacji biznesowych
- zapisuje wynik do wskazanego pliku
- dopisuje wpisy audytowe do pliku audit log

Kod wyjscia:

- `0` dla `success`
- `1` dla `invalid` albo `failure`

### Tryb ciagly

Przed startem trybu ciaglego potrzebny jest dzialajacy `Redis`.

```bash
bin/p1-tool watch \
  --config config/config.yml \
  --sidekiq-config config/sidekiq.yml \
  --sidekiq-cron-config config/sidekiq-cron.yml
```

Tryb `watch`:

- bootstrappuje konfiguracje raz na proces
- laczy `Sidekiq` z `redis.url` z konfiguracji aplikacji
- skanuje `inbox` zgodnie z harmonogramem `sidekiq-cron`
- przetwarza pliki z `processing`
- przenosi pliki do `done` albo `invalid`
- wykonuje jedno retry dla bledow technicznych i przejsciowych

Najprostsza sekwencja startowa jest taka:

```bash
docker compose -f docker-compose.dev.yml up -d redis
bin/p1-tool watch \
  --config config/config.yml \
  --sidekiq-config config/sidekiq.yml \
  --sidekiq-cron-config config/sidekiq-cron.yml
```

### Recovery

```bash
bin/p1-tool recover --config config/config.yml
```

Komenda:

- laduje konfiguracje aplikacji bez walidacji runtime
- przygotowuje workspace
- przenosi zalegle pliki z `processing` z powrotem do `inbox`
- nie wymaga walidacji certyfikatow ani dostepu do P1

### Pozostale komendy CLI

```bash
bin/p1-tool help
bin/p1-tool version
```

### Narzedzie wdrozeniowe MVP

`bin/p1-live-smoke` jest pomocniczym narzedziem do wdrazania i recznej weryfikacji MVP.
Nie jest traktowane jako stabilny kontrakt operacyjny runtime.

## Kontrakt wejscia

Minimalny plik wejsciowy musi zawierac:

- `task_id`
- `operation_kind`
- `payload`
- opcjonalnie `options`

Obslugiwane wartosci `operation_kind`:

- `register_encounter`
- `register_procedure`
- `register_condition`
- `register_provenance`
- `get_resource`
- `destroy_resource`

Przyklad:

```json
{
  "task_id": "task-1",
  "operation_kind": "register_encounter",
  "payload": {
    "patient": {
      "pesel": "75061134485",
      "first_name": "Dorota",
      "last_name": "Kalandyk"
    },
    "doctor": {
      "npwz": "3548362",
      "profession_code": "LEK",
      "name": "Dorota358 Leczniczy"
    },
    "encounter": {
      "class_code": "4",
      "start_time": "2021-09-28T12:30:00+02:00",
      "end_time": "2021-09-28T13:00:00+02:00"
    }
  }
}
```

## Wynik wykonania

Plik wynikowy zawiera m.in.:

- `transport_id`
- `task_id`
- `operation_kind`
- `result_kind`
- `config_version`
- `attempt`
- `started_at`
- `finished_at`
- opcjonalne `error`
- opcjonalne `details`

Mozliwe wartosci `result_kind`:

- `success`
- `invalid`
- `failure`

## Audyt

Audyt jest zapisywany do jednego pliku append-only w formacie JSON Lines.

Zapisywane sa zdarzenia:

- `execution_started`
- `execution_finished`
- `execution_error`

## Ograniczenia obecnej wersji

Obecna wersja nie udostepnia jeszcze:

- uruchamiania aplikacji Ruby przez `docker compose`
- podstawowego HTTP API dla runtime
- UI uzytkowego

## Lokalne uruchomienie i weryfikacja krok po kroku

Ta procedura jest podstawowa sciezka sprawdzenia aplikacji po lokalnym przygotowaniu konfiguracji.
Scenariusze wykonuj na srodowisku `integration`, z poprawnymi certyfikatami WSS/TLS i haslami w envach wskazanych w `config/config.yml`.
Scenariusze `run-once` i `watch` z fixture `register_encounter_input.json` wykonuja realne wywolania P1 i moga tworzyc zasoby w srodowisku integracyjnym.

1. przygotuj projekt:

```bash
bundle install
cp config/config.example.yml config/config.yml
cp .env.example .env
```

2. ustaw lokalne sciezki i sekrety w `.env`:

```dotenv
P1_DATA_ROOT=./tmp/local/data
P1_LOGS_ROOT=./tmp/local/logs
P1_CERTIFICATES_BASE_PATH=/sciezka/do/certyfikatow
REDIS_URL=redis://127.0.0.1:6379/0
WSS_CERT_PASSWORD=...
TLS_CERT_PASSWORD=...
```

Katalogi `inbox`, `processing`, `done`, `invalid`, `results` i `audit_log` powstana automatycznie.
Katalogi robocze musza byc na tym samym filesystemie.

3. zweryfikuj konfiguracje:

```bash
bin/p1-tool verify --config config/config.yml
```

Oczekiwany efekt:

- kod wyjscia `0`
- komunikat `Configuration OK`

4. sprawdz tryb jednorazowy `run-once`:

```bash
bin/p1-tool run-once \
  --config config/config.yml \
  --input spec/fixtures/runtime/register_encounter_input.json \
  --output tmp/local/manual-output.json
```

Oczekiwany efekt:

- kod wyjscia `0`
- komunikat `Execution finished with success`
- plik `tmp/local/manual-output.json`
- wpisy audytu w `tmp/local/logs/audit.jsonl`

5. sprawdz scenariusz niepoprawnego wejscia:

```bash
bin/p1-tool run-once \
  --config config/config.yml \
  --input spec/fixtures/runtime/invalid_input_missing_operation_kind.json \
  --output tmp/local/manual-invalid-output.json
```

Oczekiwany efekt:

- kod wyjscia `1`
- komunikat `Execution finished with invalid`
- plik `tmp/local/manual-invalid-output.json`
- w wyniku `result_kind` ma wartosc `invalid`

6. uruchom Redisa do trybu `watch` i testu integracyjnego:

```bash
docker compose -f docker-compose.dev.yml up -d redis
```

7. uruchom tryb ciagly `watch`:

```bash
bin/p1-tool watch \
  --config config/config.yml \
  --sidekiq-config config/sidekiq.yml \
  --sidekiq-cron-config config/sidekiq-cron.yml
```

Oczekiwany efekt po starcie:

- komunikat `Continuous mode started`
- polaczenie z Redisem z `redis.url`

8. w drugim terminalu wrzuc plik do `inbox`:

```bash
cp spec/fixtures/runtime/register_encounter_input.json tmp/local/data/inbox/task-1.json
```

Po przetworzeniu sprawdz:

```bash
find tmp/local -maxdepth 4 -type f | sort
cat tmp/local/data/results/task-1.json.result.json
cat tmp/local/logs/audit.jsonl
```

Oczekiwany efekt:

- plik znika z `inbox`
- plik pojawia sie w `done/task-1.json`
- wynik pojawia sie w `results/task-1.json.result.json`
- wynik ma `result_kind: success`
- audit ma zdarzenia `execution_started` i `execution_finished`

9. sprawdz scenariusz `invalid` w trybie ciagly:

```bash
cp spec/fixtures/runtime/invalid_input_missing_operation_kind.json tmp/local/data/inbox/task-invalid.json
```

Oczekiwany efekt:

- plik pojawia sie w `invalid/task-invalid.json`
- wynik pojawia sie w `results/task-invalid.json.result.json`
- wynik ma `result_kind: invalid`

10. zatrzymaj proces `watch` przez `Ctrl+C`, a potem opcjonalnie sprawdz `recover`:

```bash
mkdir -p tmp/local/data/processing
cp spec/fixtures/runtime/register_encounter_input.json tmp/local/data/processing/task-recover.json
bin/p1-tool recover --config config/config.yml
```

Oczekiwany efekt:

- komunikat `Recovery finished`
- komunikat `Recovered files: 1`
- plik znika z `processing`
- plik pojawia sie w `inbox/task-recover.json`

11. zatrzymaj Redisa i wyczysc lokalne artefakty, jesli nie sa juz potrzebne:

```bash
docker compose -f docker-compose.dev.yml down
rm -rf tmp/local
```

`bin/p1-live-smoke` moze byc uzyte pomocniczo przy wdrazaniu MVP, ale nie jest podstawowa procedura testera.

## Testy

Szybki zestaw jednostkowy:

```bash
bundle exec rake test:unit
```

Testy generuja raport pokrycia w `coverage/index.html`.
Na tym etapie coverage jest metryka informacyjna i nie blokuje uruchomienia testow minimalnym progiem.

Test integracyjny trybu ciaglego uzywa prawdziwego `redis`, ale sam test nie podnosi uslugi.
Jesli `redis` nie dziala, test integracyjny zostanie oznaczony jako `skip`.

Uruchomienie Redisa:

```bash
docker compose -f docker-compose.dev.yml up -d redis
```

Test integracyjny:

```bash
bundle exec rake test:integration
```

Pelny lokalny zestaw:

```bash
bundle exec rake test
```

Pelne lokalne uruchomienie z wykonanym testem integracyjnym wymaga:

- dzialajacego Dockera
- dostepnego `docker compose`
- uruchomionego `redis` z `docker-compose.dev.yml`

## Pliki referencyjne

- `config/config.example.yml` - przykladowa konfiguracja
- `.env.example` - przykladowe zmienne srodowiskowe
- `plan.md` - glowny opis kierunku projektu
