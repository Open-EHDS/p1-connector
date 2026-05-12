# Encounter demo

Ten rozdzial opisuje operacje `register_encounter`.

## Cel operacji

Operacja rejestruje zasob `Encounter` w P1.

Przebieg techniczny:

1. walidacja wejscia
2. wyszukanie pacjenta po PESEL
3. utworzenie pacjenta, jesli nie istnieje
4. utworzenie albo aktualizacja `Encounter`

Jesli `payload.encounter.resource_id` jest puste, operacja wykonuje create.
Jesli `payload.encounter.resource_id` jest obecne, operacja wykonuje update istniejacego `Encounter`.

## Kontrakt wejscia

Kazdy plik wejsciowy musi miec wspolny envelope runtime:

| Pole | Typ | Wymagane | Uwagi |
| --- | --- | --- | --- |
| `task_id` | string | tak | Id zadania widoczne potem w wyniku i audycie. |
| `operation_kind` | string | tak | Dla tej operacji musi byc rowne `register_encounter`. |
| `payload` | object | tak | Dane biznesowe operacji. |
| `options` | object | nie | Obecnie ta operacja z niego nie korzysta. |

### `payload.patient`

| Pole | Typ | Wymagane | Uwagi |
| --- | --- | --- | --- |
| `pesel` | string | tak | Identyfikator pacjenta. |
| `first_name` | string | tak | Imie pacjenta. |
| `last_name` | string | tak | Nazwisko pacjenta. |

### `payload.doctor`

| Pole | Typ | Wymagane | Uwagi |
| --- | --- | --- | --- |
| `name` | string | tak | Nazwa wyswietlana autora swiadczenia. |
| `profession_code` | string | tak | Kod ze slownika `PLMedicalEventStaffRole`. |
| `medical_profession_code` | string | warunkowo | Kod ze slownika `PLMedicalProfession`. Opcjonalny, jesli runtime umie wyliczyc go z `profession_code`; wymagany w pozostalych przypadkach. |
| `npwz` | string | warunkowo | Trzeba podac `npwz` albo `pesel`. |
| `pesel` | string | warunkowo | Trzeba podac `pesel` albo `npwz`. |

### `payload.encounter`

| Pole | Typ | Wymagane | Uwagi |
| --- | --- | --- | --- |
| `start_time` | string | tak | Data i czas w ISO8601. |
| `end_time` | string | tak | Data i czas w ISO8601. Musi byc `>= start_time`. |
| `class_code` | string | tak | Kod ze slownika `PLMedicalEventClass`. |
| `class_name` | string | nie | Wartosc pomocnicza. Jesli zostanie podana, musi odpowiadac wartosci `display` dla `class_code` ze slownika `PLMedicalEventClass`. |
| `identifier` | string | nie | Id biznesowy `Encounter`. Gdy brak, runtime wygeneruje UUID. |
| `episode_id` | string | nie | Id epizodu. Gdy brak, runtime wygeneruje UUID. |
| `resource_id` | string | nie | Gdy obecne, operacja aktualizuje istniejacy zasob. |
| `status` | string | nie | Gdy brak, ustawiane jest `finished`. |

### `payload.payer`

| Pole | Typ | Wymagane | Uwagi |
| --- | --- | --- | --- |
| `identifier_system` | string | warunkowo | Trzeba podac razem z `identifier_value`. |
| `identifier_value` | string | warunkowo | Trzeba podac razem z `identifier_system`. |

Jesli `payer` nie zostanie przekazany, runtime ustawi go automatycznie na identyfikator pacjenta oparty o PESEL.

## Domyslne zachowania

- `Encounter.class.display` jest wyprowadzane ze slownika `PLMedicalEventClass`.
- `doctor.medical_profession_code` nie musi byc podane, jesli runtime umie jednoznacznie wyliczyc `PLMedicalProfession` z `doctor.profession_code`.
- `Encounter.status`, jesli nie zostanie podane, przyjmuje wartosc `finished`.
- `payer`, jesli nie zostanie podany, jest uzupelniany identyfikatorem pacjenta opartym o PESEL.

## Zakres obslugiwanych danych

Operacja obsluguje podzbior danych potrzebny do rejestracji `Encounter` w obecnym zakresie integracji.

- Pacjenta identyfikujemy przez `patient.pesel`.
- Obslugujemy jednego uczestnika Zdarzenia Medycznego; `Encounter.participant` nie jest modelowane jako lista.
- `doctor.profession_code` walidujemy wzgledem slownika `PLMedicalEventStaffRole`.
- `doctor.medical_profession_code` jest wymagane tylko wtedy, gdy `profession_code` nie daje jednoznacznego mapowania do slownika `PLMedicalProfession`.
- Obslugujemy tylko glowne pole `Encounter.status`; domyslnie ustawiamy `finished` i nie wspieramy `Encounter.statusHistory`.
- `Encounter.location` wyprowadzamy z konfiguracji `subject`.
- `Encounter.serviceProvider` wyprowadzamy z konfiguracji `subject`.

### Uwaga o `Encounter.class`

Pole `Encounter.class` jest budowane na podstawie slownika `PLMedicalEventClass`.

- integrator musi podac `encounter.class_code`
- runtime sprawdza, czy kod istnieje w slowniku
- wartosc `display` do XML jest wyprowadzana ze slownika

## Mozliwe odpowiedzi

Kazdy wynik zapisany przez runtime ma wspolny envelope:

| Pole | Typ | Kiedy wystepuje |
| --- | --- | --- |
| `transport_id` | string | zawsze |
| `task_id` | string | zawsze |
| `operation_kind` | string | zawsze |
| `result_kind` | string | zawsze; `success`, `invalid` albo `failure` |
| `config_version` | string | zawsze |
| `attempt` | integer | zawsze |
| `started_at` | string | zawsze |
| `finished_at` | string | zawsze |
| `error` | object | dla `invalid` i `failure` |
| `details` | object | zawsze dla `success`, czesto takze dla `invalid` i `failure` |

### `success`

Przy powodzeniu `details` zawiera:

| Pole | Typ | Uwagi |
| --- | --- | --- |
| `resource_type` | string | Zawsze `Encounter`. |
| `encounter_identifier` | string | Id biznesowy `Encounter`. |
| `episode_identifier` | string | Id epizodu. |
| `patient_reference_id` | string | Referencja pacjenta w P1. |
| `patient_resolution` | object | Wynik wyszukania albo utworzenia pacjenta. |
| `submission` | object | Wynik wyslania `Encounter` do P1. |

`patient_resolution.status` przyjmuje:

- `found`
- `created`

`submission.status` przyjmuje:

- `created`
- `updated`

Przyklad wyniku `success`:

```json
{
  "transport_id": "transport-1",
  "task_id": "register-encounter-task-1",
  "operation_kind": "register_encounter",
  "result_kind": "success",
  "config_version": "<config-version>",
  "attempt": 1,
  "started_at": "2026-05-05T10:00:00Z",
  "finished_at": "2026-05-05T10:00:01Z",
  "details": {
    "resource_type": "Encounter",
    "encounter_identifier": "4adf7723-e2a8-4e4b-bc69-f2ce93072eb3",
    "episode_identifier": "dbd93c2f-fd3a-4517-b7f2-576759bca87b",
    "patient_reference_id": "stub-patient-75061134485",
    "patient_resolution": {
      "status": "found",
      "action": "find_or_create_patient",
      "patient_reference_id": "stub-patient-75061134485",
      "patient_version_id": "7"
    },
    "submission": {
      "status": "created",
      "action": "submit_encounter_to_p1",
      "submitted": true,
      "reference_id": "encounter-ref-1",
      "response_status": 201,
      "version_id": "1"
    }
  }
}
```

### `invalid`

`invalid` oznacza, ze wejscie nie przeszlo walidacji.

Typowy ksztalt:

```json
{
  "result_kind": "invalid",
  "error": {
    "code": "invalid_input",
    "message": "Register encounter payload validation failed",
    "category": "input"
  },
  "details": {
    "validation_errors": {
      "doctor": {
        "base": [
          "must include npwz or pesel"
        ]
      },
      "encounter": {
        "end_time": [
          "must be greater than or equal to start_time"
        ]
      }
    }
  }
}
```

### `failure`

`failure` oznacza blad wykonania po poprawnym przejsciu walidacji wejscia.

Najwazniejsze warianty:

- `error.category = technical` dla bledow technicznych
- `error.category = business` dla bledow z integracji biznesowej

Jesli blad pochodzi z upstreamu i niesie szczegoly HTTP, runtime dopisuje je do `error`, np.:

```json
{
  "result_kind": "failure",
  "error": {
    "code": "runtime_error",
    "message": "p1 failed",
    "category": "business",
    "http_status": 422,
    "body": {
      "issue": [
        {
          "diagnostics": "invalid payload"
        }
      ]
    }
  },
  "details": {
    "exception_class": "P1Tool::BusinessError"
  }
}
```

## Przyklad gotowego inputu

Gotowy plik znajduje sie tutaj:

- [examples/register_encounter.json](examples/register_encounter.json)

Mozna go wykorzystac bez zmian:

- jako `--input` dla `run-once`
- jako plik wrzucany do `inbox` w trybie `watch`

### `run-once`

```bash
bin/p1-tool run-once \
  --config config/config.yml \
  --input docs/demo/examples/register_encounter.json \
  --output tmp/register_encounter.result.json
```

### `watch`

```bash
cp docs/demo/examples/register_encounter.json <inbox>/register_encounter.json
```

W trybie `watch` wynik zostanie zapisany jako:

```text
<results>/register_encounter.json.result.json
```
