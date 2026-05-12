# Provenance demo

Ten rozdzial opisuje operacje `register_provenance`.

## Cel operacji

Operacja rejestruje zasob `Provenance` w P1 dla wskazanych zasobow i podpisuje ich aktualne wersje przez `signature-service`.

Przebieg techniczny:

1. walidacja wejscia
2. pobranie wskazanych zasobow z P1
3. wygenerowanie podpisu w `signature-service`
4. utworzenie albo aktualizacja `Provenance`

Jesli `payload.provenance.resource_id` jest puste, operacja wykonuje create.
Jesli `payload.provenance.resource_id` jest obecne, operacja wykonuje update istniejacego `Provenance`.

## Kontrakt wejscia

Kazdy plik wejsciowy musi miec wspolny envelope runtime:

| Pole | Typ | Wymagane | Uwagi |
| --- | --- | --- | --- |
| `task_id` | string | tak | Id zadania widoczne potem w wyniku i audycie. |
| `operation_kind` | string | tak | Dla tej operacji musi byc rowne `register_provenance`. |
| `payload` | object | tak | Dane biznesowe operacji. |
| `options` | object | nie | Obecnie ta operacja z niego nie korzysta. |

### `payload.doctor`

| Pole | Typ | Wymagane | Uwagi |
| --- | --- | --- | --- |
| `name` | string | tak | Nazwa wyswietlana operatora. |
| `profession_code` | string | tak | Kod ze slownika `PLMedicalEventStaffRole`. |
| `medical_profession_code` | string | nie | Pole akceptowane przez kontrakt wejscia. |
| `npwz` | string | warunkowo | Trzeba podac `npwz` albo `pesel`. |
| `pesel` | string | warunkowo | Trzeba podac `pesel` albo `npwz`. |

### `payload.references`

`references` to tablica obiektow. Kazdy obiekt musi zawierac:

| Pole | Typ | Wymagane | Uwagi |
| --- | --- | --- | --- |
| `resource_type` | string | tak | Typ zasobu do dolaczenia do podpisu. |
| `reference_id` | string | tak | Id zasobu w P1. |
| `version_id` | string | tak | Wersja zasobu w P1. |

Walidacja biznesowa wymaga, aby w tablicy `references` znalazly sie co najmniej:

- jeden wpis z `resource_type = Patient`
- jeden wpis z `resource_type = Encounter`

### `payload.provenance`

| Pole | Typ | Wymagane | Uwagi |
| --- | --- | --- | --- |
| `recorded_at` | string | tak | Data i czas w ISO8601. |
| `resource_id` | string | nie | Gdy obecne, operacja aktualizuje istniejacy zasob. |

## Domyslne zachowania

- runtime pobiera wskazane wersje zasobow z P1 i przekazuje ich XML do `signature-service`,
- `signature-service` zwraca podpis, ktory jest osadzany w tworzonym `Provenance`,
- w wyniku sukcesu zwracana jest lista `targets` zbudowana z `payload.references`.

## Zakres obslugiwanych danych

Operacja obsluguje podzbior danych potrzebny do rejestracji `Provenance` w obecnym zakresie integracji.

- `doctor.profession_code` walidujemy wzgledem slownika `PLMedicalEventStaffRole`.
- `references` musza zawierac co najmniej `Patient` i `Encounter`.
- kazdy wpis w `references` musi wskazywac konkretny zasob i konkretna wersje zasobu.
- operacja zalezy od poprawnej konfiguracji `signature_service.url`.
- `Provenance` jest wysylane po wygenerowaniu podpisu dla wszystkich wskazanych referencji.

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
| `resource_type` | string | Zawsze `Provenance`. |
| `targets` | array | Lista referencji uzytych do budowy `Provenance`. |
| `submission` | object | Wynik wyslania `Provenance` do P1. |

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
    "message": "Register provenance payload validation failed",
    "category": "input"
  },
  "details": {
    "validation_errors": {
      "references": {
        "base": [
          "must include Patient reference",
          "must include Encounter reference"
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

W tej operacji `failure` moze pochodzic zarowno z P1, jak i z `signature-service`.

## Przyklad gotowego inputu

Gotowy plik znajduje sie tutaj:

- [examples/register_provenance.json](examples/register_provenance.json)

Mozna go wykorzystac bez zmian po uzupelnieniu identyfikatorow i wersji:

- jako `--input` dla `run-once`
- jako plik wrzucany do `inbox` w trybie `watch`

### `run-once`

```bash
bin/p1-tool run-once \
  --config config/config.yml \
  --input docs/demo/examples/register_provenance.json \
  --output tmp/register_provenance.result.json
```

### `watch`

```bash
cp docs/demo/examples/register_provenance.json <inbox>/register_provenance.json
```

W trybie `watch` wynik zostanie zapisany jako:

```text
<results>/register_provenance.json.result.json
```
