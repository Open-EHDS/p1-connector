# Get resource demo

Ten rozdzial opisuje operacje `get_resource`.

## Cel operacji

Operacja pobiera XML wskazanego zasobu z P1.

## Kontrakt wejscia

Kazdy plik wejsciowy musi miec wspolny envelope runtime:

| Pole | Typ | Wymagane | Uwagi |
| --- | --- | --- | --- |
| `task_id` | string | tak | Id zadania widoczne potem w wyniku i audycie. |
| `operation_kind` | string | tak | Dla tej operacji musi byc rowne `get_resource`. |
| `payload` | object | tak | Dane biznesowe operacji. |
| `options` | object | nie | Obecnie ta operacja z niego nie korzysta. |

### `payload.doctor`

| Pole | Typ | Wymagane | Uwagi |
| --- | --- | --- | --- |
| `name` | string | tak | Nazwa wyswietlana operatora. |
| `profession_code` | string | tak | Kod ze slownika `PLMedicalEventStaffRole`. |
| `npwz` | string | warunkowo | Trzeba podac `npwz` albo `pesel`. |
| `pesel` | string | warunkowo | Trzeba podac `pesel` albo `npwz`. |

### `payload.resource`

| Pole | Typ | Wymagane | Uwagi |
| --- | --- | --- | --- |
| `resource_type` | string | tak | Jedna z wartosci: `Patient`, `Encounter`, `Procedure`, `Condition`, `Provenance`. |
| `resource_id` | string | tak | Id zasobu w P1. |
| `version_id` | string | nie | Jesli zostanie podane, runtime pobiera konkretna wersje z `_history`. |

## Zakres obslugiwanych danych

Operacja obsluguje odczyt XML dla typow:

- `Patient`
- `Encounter`
- `Procedure`
- `Condition`
- `Provenance`

`doctor.profession_code` walidujemy wzgledem slownika `PLMedicalEventStaffRole`.

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
| `resource_type` | string | Typ pobranego zasobu. |
| `reference_id` | string | Id zasobu w P1. |
| `version_id` | string | Wersja zasobu, jesli byla podana lub zwrocona. |
| `xml` | string | XML zasobu zwrocony przez P1. |
| `content_type` | string | Typ MIME odpowiedzi z P1. |
| `response_status` | integer | Status HTTP odpowiedzi z P1. |

### `invalid`

`invalid` oznacza, ze wejscie nie przeszlo walidacji.

Typowy ksztalt:

```json
{
  "result_kind": "invalid",
  "error": {
    "code": "invalid_input",
    "message": "Get resource payload validation failed",
    "category": "input"
  },
  "details": {
    "validation_errors": {
      "resource": {
        "resource_type": [
          "must be one of: Patient, Encounter, Procedure, Condition, Provenance"
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

- [examples/get_resource.json](examples/get_resource.json)

Mozna go wykorzystac po uzupelnieniu identyfikatorow:

- jako `--input` dla `run-once`
- jako plik wrzucany do `inbox` w trybie `watch`

### `run-once`

```bash
bin/p1-tool run-once \
  --config config/config.yml \
  --input docs/demo/examples/get_resource.json \
  --output tmp/get_resource.result.json
```

### `watch`

```bash
cp docs/demo/examples/get_resource.json <inbox>/get_resource.json
```

W trybie `watch` wynik zostanie zapisany jako:

```text
<results>/get_resource.json.result.json
```
