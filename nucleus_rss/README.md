# Nucleus RSS

Nucleus RSS ist ein lokaler, datenschutzfokussierter RSS-Reader, der speziell für das Google Pixel 8 (Material You, 120Hz) entwickelt wurde. Er läuft zu 100% On-Device, ohne Proxy oder Cloud-Backend, und verarbeitet Feeds über Dart Isolates.

## Architektur & Core-Stack

- **Framework**: Flutter (Latest Stable)
- **State Management**: Riverpod (flutter_riverpod)
- **Local Storage**: Drift (SQLite)
- **Networking**: Direktes Client-Side Fetching (http, dart_rss)
- **ML / On-Device Intelligence**: google_mlkit_entity_extraction via Dart Compute (Isolates)

## "Für Dich" Scoring-Algorithmus

Der "Für Dich" (For You) Feed kombiniert Benutzerinteressen und die Aktualität der Artikel zu einem personalisierten Feed. Das gesamte Profil verlässt das Gerät nie.

Die mathematische Formel zur Berechnung der Relevanz lautet:
`Gesamt_Score = (Interesse_an_Kategorie * 0.7) + (Aktualität * 0.3)`

**Interesse_an_Kategorie**:
Das Interesse an einer Kategorie wird durch einen `globalWeight`-Wert repräsentiert. Jedes Mal, wenn der Nutzer auf einen Artikel in der Timeline tippt, erhöht sich das Gewicht der dazugehörigen Kategorie um `1.0`.

**Aktualität (Recency)**:
Die Aktualität fällt linear über 168 Stunden (7 Tage) ab, beginnend bei `1.0` (jetzt) und endend bei `0.0` (7 Tage alt oder älter).
`Aktualität = max(0, 1.0 - (Alter_in_Stunden / 168.0))`

Dadurch wird sichergestellt, dass Themen, die den Nutzer brennend interessieren, weit oben im Feed stehen, aber völlig veraltete Artikel zugunsten neuerer Inhalte allmählich abgewertet werden.

## Lokales Machine Learning (ML Kit)

Wenn ein Artikel über den OPML-Import importiert wird (oder ein Feed aktualisiert wird), durchläuft er den `ClassifierService`. Dieser Service extrahiert den Titel und die Beschreibung des Artikels.
1. **Entity Extraction**: Mittels Googles ML Kit (`google_mlkit_entity_extraction`) wird die Sprache des Textes identifiziert und relevante Entities lokal auf dem Gerät erkannt.
2. **Heuristiken**: Der erkannte Text (und die ML Entities) wird gegen vordefinierte Kategorien ("Linux", "Tech", "Mobile") abgeglichen.
3. **Isolates**: Um das flüssige 120Hz-Erlebnis auf dem Pixel 8 zu erhalten, werden die rechenintensiven Aufgaben in Dart Isolates (`compute()`) und im Hintergrund über native ML Kit Threads abgearbeitet.

## Einstieg
Die App startet komplett leer.
Tippe auf das Upload-Icon oben rechts, um eine `.opml` oder `.xml` Feed-Liste aus Apps wie FeedFlow zu importieren.
