# Procedure demo

Ten rozdzial opisuje operacje `register_procedure`.

## Cel operacji

Operacja rejestruje zasob `Procedure` w P1 i wiaze go z istniejacym `Encounter`.

Przebieg techniczny:

1. walidacja wejscia
2. wyszukanie pacjenta po PESEL
3. utworzenie pacjenta, jesli nie istnieje
4. utworzenie albo aktualizacja `Procedure`

Jesli `payload.procedure.resource_id` jest puste, operacja wykonuje create.
Jesli `payload.procedure.resource_id` jest obecne, operacja wykonuje update istniejacego `Procedure`.

## Kontrakt wejscia

Kazdy plik wejsciowy musi miec wspolny envelope runtime:

| Pole | Typ | Wymagane | Uwagi |
| --- | --- | --- | --- |
| `task_id` | string | tak | Id zadania widoczne potem w wyniku i audycie. |
| `operation_kind` | string | tak | Dla tej operacji musi byc rowne `register_procedure`. |
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
| `name` | string | tak | Nazwa wyswietlana autora procedury. |
| `profession_code` | string | tak | Kod ze slownika `PLMedicalEventStaffRole`. |
| `medical_profession_code` | string | warunkowo | Kod ze slownika `PLMedicalProfession`. Opcjonalny, jesli runtime umie wyliczyc go z `profession_code`; wymagany w pozostalych przypadkach. |
| `npwz` | string | warunkowo | Trzeba podac `npwz` albo `pesel`. |
| `pesel` | string | warunkowo | Trzeba podac `pesel` albo `npwz`. |

### `payload.encounter`

| Pole | Typ | Wymagane | Uwagi |
| --- | --- | --- | --- |
| `resource_id` | string | tak | Referencja do istniejacego `Encounter` w P1. |

### `payload.procedure`

| Pole | Typ | Wymagane | Uwagi |
| --- | --- | --- | --- |
| `icd_9_code` | string | tak | Kod procedury. |
| `icd_9_name` | string | tak | Nazwa procedury. |
| `start_time` | string | tak | Data i czas w ISO8601. |
| `end_time` | string | tak | Data i czas w ISO8601. Musi byc `>= start_time`. |
| `element_code` | string | nie | Kod elementu z katalogu P1. Jesli zostanie podany, musi istniec w katalogu elementow. |
| `resource_id` | string | nie | Gdy obecne, operacja aktualizuje istniejacy zasob. |
| `status` | string | nie | Gdy brak, ustawiane jest `completed`. |

## Domyslne zachowania

- `procedure.status`, jesli nie zostanie podane, przyjmuje wartosc `completed`.
- `doctor.medical_profession_code` nie musi byc podane, jesli runtime umie jednoznacznie wyliczyc `PLMedicalProfession` z `doctor.profession_code`.

## Zakres obslugiwanych danych

Operacja obsluguje podzbior danych potrzebny do rejestracji `Procedure` w obecnym zakresie integracji.

- Pacjenta identyfikujemy przez `patient.pesel`.
- `encounter.resource_id` musi wskazywac istniejacy `Encounter`.
- `doctor.profession_code` walidujemy wzgledem slownika `PLMedicalEventStaffRole`.
- `doctor.medical_profession_code` jest wymagane tylko wtedy, gdy `profession_code` nie daje jednoznacznego mapowania do slownika `PLMedicalProfession`.
- `procedure.element_code`, jesli zostanie podane, walidujemy wzgledem katalogu elementow P1.
- `Procedure.location` wyprowadzamy z konfiguracji `subject`.
- Obslugujemy pojedynczy okres procedury opisany przez `start_time` i `end_time`.

## Uproszczenia modelu integratora

Wzgledem pelnego profilu `PLMedicalEventProcedure` integrator upraszcza model do podstawowych danych potrzebnych do rejestracji procedury w kontekscie jednego `Encounter`.

- obslugiwany jest tylko profil `PLMedicalEventProcedure`,
- przekazujemy jeden kod procedury: `icd_9_code` i `icd_9_name`,
- przekazujemy jeden okres wykonania: `start_time` i `end_time`,
- przekazujemy jednego autora procedury w galezi `Procedure.asserter`,
- nie modelujemy listy `Procedure.performer`,
- nie modelujemy `Procedure.basedOn`,
- nie modelujemy `Procedure.focalDevice`,
- nie modelujemy wielu `Procedure.bodySite`; opcjonalnie przekazujemy jedno `bodySite` przez `element_code`,
- `Procedure.location` nie jest przekazywane w payloadzie biznesowym, tylko wyprowadzane z konfiguracji `subject`,
- `procedure.status` moze byc przekazane jawnie, ale gdy go brak, runtime ustawia `completed`.

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
| `resource_type` | string | Zawsze `Procedure`. |
| `encounter_reference_id` | string | Referencja `Encounter` powiazana z procedura. |
| `patient_reference_id` | string | Referencja pacjenta w P1. |
| `patient_resolution` | object | Wynik wyszukania albo utworzenia pacjenta. |
| `submission` | object | Wynik wyslania `Procedure` do P1. |

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
    "message": "Register procedure payload validation failed",
    "category": "input"
  },
  "details": {
    "validation_errors": {
      "procedure": {
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

## Przyklad gotowego inputu

Gotowy plik znajduje sie tutaj:

- [examples/register_procedure.json](examples/register_procedure.json)

Mozna go wykorzystac bez zmian:

- jako `--input` dla `run-once`
- jako plik wrzucany do `inbox` w trybie `watch`

### `run-once`

```bash
bin/p1-tool run-once \
  --config config/config.yml \
  --input docs/demo/examples/register_procedure.json \
  --output tmp/register_procedure.result.json
```

### `watch`

```bash
cp docs/demo/examples/register_procedure.json <inbox>/register_procedure.json
```

W trybie `watch` wynik zostanie zapisany jako:

```text
<results>/register_procedure.json.result.json
```
