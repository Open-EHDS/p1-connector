# Contributing

Dziekujemy za chec kontrybucji do `p1-connector`.

## Model pracy

- Glowna i chroniona galezia repozytorium to `main`.
- Nie uzywamy stalej galezi `develop`.
- Zmiany trafiaja do `main` przez pull request.
- Domyslnym sposobem merge jest squash merge.
- Po merge galezie robocze sa usuwane automatycznie.

## Pull requesty

1. Utworz branch z krotka, opisowa nazwa.
2. Przygotuj zmiane w mozliwie spojnym zakresie.
3. Uruchom adekwatne testy.
4. Otworz PR do `main` i wypelnij szablon.
5. Poczekaj na wymagana recenzje maintainerow oraz review CODEOWNERS.

Minimalny standard PR:

- 1 approval.
- Review CODEOWNERS.
- Rozwiazane komentarze przed merge.
- Zielony CI, gdy repozytorium ma aktywny stabilny workflow dla danego zakresu.

## Uprawnienia

Dostep do repozytorium jest zarzadzany przez teamy organizacji GitHub, nie przez bezposrednich collaboratorow. Dla tego repo podstawowym teamem utrzymujacym jest `@Open-EHDS/p1-connector-maintainers`.

## Testy

Podstawowy lokalny zestaw jakosci:

```bash
bundle exec rake quality
```

Testy integracyjne z Redis:

```bash
INTEGRATION_REDIS_URL=redis://127.0.0.1:6379/0 REQUIRE_REDIS_INTEGRATION=1 bundle exec rake test:integration
```

Testy narzedzia podpisu:

```bash
cd services/signature-tool
./gradlew test
```

## Sekrety i dane wrazliwe

Nie commituj:

- sekretow,
- certyfikatow,
- danych pacjentow,
- danych srodowiskowych produkcji,
- wygenerowanych plikow roboczych z integracji P1.

Jesli przypadkowo trafia do repo sekret albo dane wrazliwe, nie naprawiaj tego samym usunieciem pliku w kolejnym commicie. Zglos incydent maintainerom, zeby mozna bylo wykonac rotacje i czyszczenie historii, jesli bedzie potrzebne.
