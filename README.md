# p1-connector

Lekki runtime Ruby do integracji plikowej z platforma P1.

## Dla kogo jest ten projekt

To narzedzie jest przygotowywane dla integratora, ktory chce uruchamiac zadania wsadowe przekazywane jako pliki JSON i odbierac wynik w postaci pliku JSON oraz wpisow audytowych.

Na obecnym etapie projekt udostepnia lokalny tryb jednorazowego wykonania `run-once`, tryb ciagly `watch` oparty o `Sidekiq`, `sidekiq-cron` i `Redis`, komende operatorska `recover` oraz pomocniczy runner `p1-live-smoke`.

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
- `bin/p1-live-smoke` - sekwencyjny smoke runner dla `Encounter`, opcjonalnie `Procedure`, `Condition` i `Provenance`

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

### Smoke runner

```bash
bin/p1-live-smoke \
  --config config/config.yml \
  --input spec/fixtures/runtime/register_encounter_input.json \
  --procedure-input spec/fixtures/runtime/register_procedure_input.json \
  --condition-input spec/fixtures/runtime/register_condition_input.json \
  --provenance-input spec/fixtures/runtime/register_provenance_input.json \
  --clean
```

Runner:

- uruchamia `run-once` dla `register_encounter`
- moze potem odpalic `register_procedure`, `register_condition` i `register_provenance`
- po wykonaniu probuje usunac utworzone zasoby w odwrotnej kolejnosci: `Provenance`, `Condition`, `Procedure`, `Encounter`
- zapisuje artefakty do `tmp/live_smoke/...`
- tymczasowo ustawia `P1_DEBUG_XML=1` i `P1_DEBUG_XML_PATH` na katalog artefaktow danego przebiegu

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

## Szybka lokalna weryfikacja

Jesli chcesz szybko sprawdzic aktualny stan aplikacji lokalnie, przejdz ten skrot:

1. przygotuj projekt:

```bash
bundle install
cp config/config.example.yml config/config.yml
cp .env.example .env
```

Nastepnie:

- ustaw `WSS_CERT_PASSWORD` i `TLS_CERT_PASSWORD`
- dopasuj `P1_CERTIFICATES_BASE_PATH`, jesli certyfikaty nie leza pod `./volumes/certs`

2. zweryfikuj konfiguracje:

```bash
bin/p1-tool verify --config config/config.yml
```

3. sprawdz tryb jednorazowy:

```bash
bin/p1-tool run-once \
  --config config/config.yml \
  --input spec/fixtures/runtime/register_encounter_input.json \
  --output tmp/tester/manual-output.json
```

4. uruchom Redisa do trybu `watch` i testu integracyjnego:

```bash
docker compose -f docker-compose.dev.yml up -d redis
```

5. uruchom tryb ciagly:

```bash
bin/p1-tool watch \
  --config config/config.yml \
  --sidekiq-config config/sidekiq.yml \
  --sidekiq-cron-config config/sidekiq-cron.yml
```

6. w drugim terminalu wrzuc plik do `inbox` i potwierdz wynik w `results` oraz przeniesienie pliku do `done`
7. opcjonalnie sprawdz `recover`:

```bash
bin/p1-tool recover --config config/config.yml
```

Pelna checklista testera, razem z oczekiwanymi rezultatami, scenariuszem `invalid`, recovery i sprzataniem, jest w [docs/tester-local-checklist.md](docs/tester-local-checklist.md).

8. opcjonalnie uruchom pelniejszy smoke flow:

```bash
bin/p1-live-smoke \
  --config config/config.yml \
  --input spec/fixtures/runtime/register_encounter_input.json \
  --procedure-input spec/fixtures/runtime/register_procedure_input.json \
  --condition-input spec/fixtures/runtime/register_condition_input.json \
  --provenance-input spec/fixtures/runtime/register_provenance_input.json \
  --clean
```

## Testy

Pelny zestaw testow uruchamia takze test integracyjny z prawdziwym `redis`, ale sam test nie podnosi uslugi.
Najpierw developer uruchamia `redis` z compose:

```bash
docker compose -f docker-compose.dev.yml up -d redis
```

Potem mozna uruchomic:

```bash
bundle exec rake test
```

Dostepne sa tez rozbite taski:

```bash
bundle exec rake test:unit
bundle exec rake test:integration
```

To oznacza, ze pelne lokalne uruchomienie testow wymaga:

- dzialajacego Dockera
- dostepnego `docker compose`

Jesli potrzebujesz pelnej procedury manualnej, a nie tylko uruchomienia testow automatycznych, zobacz [docs/tester-local-checklist.md](docs/tester-local-checklist.md).

## Pliki referencyjne

- `config/config.example.yml` - przykladowa konfiguracja
- `.env.example` - przykladowe zmienne srodowiskowe
- `docs/tester-local-checklist.md` - pelna lokalna checklista testera
- `plan.md` - glowny opis kierunku projektu
