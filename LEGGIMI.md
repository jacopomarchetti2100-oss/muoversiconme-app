# Muoversi con Me · Area clienti

Indirizzo: https://app.muoversiconme.it
Progetto separato dal sito vetrina: nessun link tra i due, l'indirizzo si dà solo ai clienti.

## Cosa c'è
- `index.html`: login, scheda esercizi, caricamento video, chat (beta: cliente PAKE / 1234, coach ALE / 4321).
- `CNAME`: dice a GitHub Pages di usare il dominio app.muoversiconme.it.
- `fonts/`, `img/`: solo i file che servono a questa pagina.
- Il tag `<meta name="robots" content="noindex, nofollow">` in `index.html` tiene la pagina fuori da Google.

## Versione beta
Video e messaggi restano nel browser di chi li usa. Nel prossimo passo login, video e chat passeranno da Supabase.
