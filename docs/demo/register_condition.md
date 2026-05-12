# Condition demo

Ten rozdzial opisuje operacje `register_condition`.

## Cel operacji

Operacja rejestruje zasob `Condition` w P1 i wiaze go z istniejacym `Encounter`.

Przebieg techniczny:

1. walidacja wejscia
2. wyszukanie pacjenta po PESEL
3. utworzenie pacjenta, jesli nie istnieje
4. utworzenie albo aktualizacja `Condition`

Jesli `payload.condition.resource_id` jest puste, operacja wykonuje create.
Jesli `payload.condition.resource_id` jest obecne, operacja wykonuje update istniejacego `Condition`.

## Kontrakt wejscia

Kazdy plik wejsciowy musi miec wspolny envelope runtime:

| Pole | Typ | Wymagane | Uwagi |
| --- | --- | --- | --- |
| `task_id` | string | tak | Id zadania widoczne potem w wyniku i audycie. |
| `operation_kind` | string | tak | Dla tej operacji musi byc rowne `register_condition`. |
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
| `name` | string | tak | Nazwa wyswietlana autora rozpoznania. |
| `profession_code` | string | tak | Kod ze slownika `PLMedicalEventStaffRole`. |
| `medical_profession_code` | string | warunkowo | Kod ze slownika `PLMedicalProfession`. Opcjonalny, jesli runtime umie wyliczyc go z `profession_code`; wymagany w pozostalych przypadkach. |
| `npwz` | string | warunkowo | Trzeba podac `npwz` albo `pesel`. |
| `pesel` | string | warunkowo | Trzeba podac `pesel` albo `npwz`. |

### `payload.encounter`

| Pole | Typ | Wymagane | Uwagi |
| --- | --- | --- | --- |
| `resource_id` | string | tak | Referencja do istniejacego `Encounter` w P1. |

### `payload.condition`

| Pole | Typ | Wymagane | Uwagi |
| --- | --- | --- | --- |
| `icd_10_code` | string | tak | Kod rozpoznania. |
| `icd_10_name` | string | tak | Nazwa rozpoznania. |
| `recorded_date` | string | tak | Data i czas w ISO8601. |
| `element_code` | string | nie | Kod elementu z katalogu P1. Jesli zostanie podany, musi istniec w katalogu elementow. |
| `category` | string | nie | Dopuszczalne wartosci: `main`, `concurrent`. |
| `resource_id` | string | nie | Gdy obecne, operacja aktualizuje istniejacy zasob. |

## Domyslne zachowania

- `condition.category`, jesli nie zostanie podane, przyjmuje wartosc `main`.
- `condition.category.display` jest wyprowadzane na podstawie `category`.
- `doctor.medical_profession_code` nie musi byc podane, jesli runtime umie jednoznacznie wyliczyc `PLMedicalProfession` z `doctor.profession_code`.

## Zakres obslugiwanych danych

Operacja obsluguje podzbior danych potrzebny do rejestracji `Condition` w obecnym zakresie integracji.

- Pacjenta identyfikujemy przez `patient.pesel`.
- `encounter.resource_id` musi wskazywac istniejacy `Encounter`.
- `doctor.profession_code` walidujemy wzgledem slownika `PLMedicalEventStaffRole`.
- `doctor.medical_profession_code` jest wymagane tylko wtedy, gdy `profession_code` nie daje jednoznacznego mapowania do slownika `PLMedicalProfession`.
- `condition.element_code`, jesli zostanie podane, walidujemy wzgledem katalogu elementow P1.
- `Condition.category` wspiera wartosci `main` i `concurrent`.
- `Condition.location` wyprowadzamy z konfiguracji `subject`.

## Uproszczenia modelu integratora

Wzgledem pelnego profilu `PLMedicalEventDiagnosis` integrator upraszcza model do podstawowych danych potrzebnych do rejestracji rozpoznania w kontekscie jednego `Encounter`.

- przekazujemy jeden kod rozpoznania: `icd_10_code` i `icd_10_name`,
- przekazujemy jedna kategorie rozpoznania: `main` albo `concurrent`,
- przekazujemy jedno `recorded_date`,
- przekazujemy jednego autora rozpoznania w galezi `Condition.asserter`,
- nie modelujemy `Condition.clinicalStatus`,
- nie modelujemy `Condition.verificationStatus`,
- nie modelujemy `Condition.evidence`,
- nie modelujemy `Condition.extension:pointOfEncounter`,
- nie modelujemy `Condition.pregnancyWeek`,
- nie modelujemy wielu `Condition.bodySite`; opcjonalnie przekazujemy jedno `bodySite` przez `element_code`,
- `Condition.location` nie jest przekazywane w payloadzie biznesowym, tylko wyprowadzane z konfiguracji `subject`,
- obecna integracja zaklada kodowanie rozpoznania przez ICD-10.

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
| `resource_type` | string | Zawsze `Condition`. |
| `encounter_reference_id` | string | Referencja `Encounter` powiazana z rozpoznaniem. |
| `patient_reference_id` | string | Referencja pacjenta w P1. |
| `patient_resolution` | object | Wynik wyszukania albo utworzenia pacjenta. |
| `submission` | object | Wynik wyslania `Condition` do P1. |

`patient_resolution.status` przyjmuje:

- `found`
- `created`

`submission.status` przyjmuje:

- `created`
- `updated`

### `invalid`

`invalid` oznacza, ze wejscie nie przeszlo walidacji.

Typowy ksztalt:

```json
{
  "result_kind": "invalid",
  "error": {
    "code": "invalid_input",
    "message": "Register condition payload validation failed",
    "category": "input"
  },
  "details": {
    "validation_errors": {
      "condition": {
        "category": [
          "must be one of: main, concurrent"
        ],
        "recorded_date": [
          "must be a valid ISO8601 date time"
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

## Przyklad gotowego inputu

Gotowy plik znajduje sie tutaj:

- [examples/register_condition.json](examples/register_condition.json)

Mozna go wykorzystac bez zmian:

- jako `--input` dla `run-once`
- jako plik wrzucany do `inbox` w trybie `watch`

### `run-once`

```bash
bin/p1-tool run-once \
  --config config/config.yml \
  --input docs/demo/examples/register_condition.json \
  --output tmp/register_condition.result.json
```

### `watch`

```bash
cp docs/demo/examples/register_condition.json <inbox>/register_condition.json
```

W trybie `watch` wynik zostanie zapisany jako:

```text
<results>/register_condition.json.result.json
```
