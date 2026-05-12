# signature-tool

`signature-tool` generuje detached XAdES dla dokumentow przekazanych przez `p1-connector`. Nie laczy sie z P1 i nie zna tokenow ani TLS do ISUS/SUS.

Kod komponentu jest trzymany w `services/signature-tool`.

## Model pracy

- `p1-connector` pobiera dokumenty z P1
- `p1-connector` wysyla je do `signature-tool`
- `signature-tool` zwraca podpis XML
- `p1-connector` osadza go w `Provenance.signature.data`

W tej wersji:
- request zawiera tylko `documents`
- certyfikat WSS jest montowany do kontenera
- haslo do certyfikatu jest podawane przez ENV albo plik secret

## API

Endpoint:

```text
POST /api/v1/signatures/xades-detached
```

Request:

```json
{
  "documents": [
    {
      "uri": "https://isus.ezdrowie.gov.pl/fhir/Patient/123/_history/7",
      "mimeType": "application/fhir+xml",
      "content": "<Patient xmlns=\"http://hl7.org/fhir\">...</Patient>"
    },
    {
      "uri": "https://isus.ezdrowie.gov.pl/fhir/Encounter/456/_history/1",
      "mimeType": "application/fhir+xml",
      "content": "<Encounter xmlns=\"http://hl7.org/fhir\">...</Encounter>"
    }
  ]
}
```

Response:

```json
{
  "document": "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?><ds:Signature ...",
  "documentBase64": "PD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0iVVRGLTgiIHN0YW5kYWxvbmU9Im5vIj8+..."
}
```

## Konfiguracja

Wymagane:

- `SIGNATURE_TOOL_SIGNING_CERTIFICATE_PATH`

Jedno z:

- `SIGNATURE_TOOL_SIGNING_PASSWORD`
- `SIGNATURE_TOOL_SIGNING_PASSWORD_FILE`

Przyklad:

```bash
export SIGNATURE_TOOL_SIGNING_CERTIFICATE_PATH=/certs/wss.p12
export SIGNATURE_TOOL_SIGNING_PASSWORD=bTg6WRRfTjjA
cd services/signature-tool
./gradlew bootRun
```

## Docker

Build:

```bash
docker build -t signature-tool:local services/signature-tool
```

Run:

```bash
docker run --rm \
  -p 8080:8080 \
  -e SIGNATURE_TOOL_SIGNING_CERTIFICATE_PATH=/certs/wss.p12 \
  -e SIGNATURE_TOOL_SIGNING_PASSWORD=bTg6WRRfTjjA \
  -v /local/path/to/certs:/certs:ro \
  signature-tool:local
```

## Testy

```bash
cd services/signature-tool
./gradlew test
```

W repo jest test integracyjny podpisu korzystajacy z testowego certyfikatu w `src/test/resources/fixtures/CezarySzybki.pfx`.
