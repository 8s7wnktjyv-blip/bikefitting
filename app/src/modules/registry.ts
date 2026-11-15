// Alle Module der Plattform mit ehrlichem Stand in der NEUEN App.
// 'alt'  = läuft weiter in der bisherigen App (index.html), noch nicht übertragen
// 'neu'  = in der neuen App umgesetzt
// 'fehlt'= gibt es noch nirgends
export type ModStatus = 'neu' | 'alt' | 'fehlt';
export type Mod = { id: string; label: string; area: string; status: ModStatus; legacy?: string; note: string };

export const MODULES: Mod[] = [
  { id: 'cockpit', label: 'Cockpit', area: 'A', status: 'neu', note: 'Grundgerüst: Anmeldung, Laden, Stand der Übertragung' },
  { id: 'kunden', label: 'Kunden', area: 'B', status: 'neu', legacy: 'kunden', note: 'Liste, Suche, Firmen, Ansprechpartner, Wiedervorlagen, Räder, Aufträge – vorerst nur lesen' },
  { id: 'pass', label: 'Fahrradpass', area: 'C', status: 'alt', legacy: 'fahrraeder', note: 'Läuft auf eigenen Tabellen und bleibt erhalten' },
  { id: 'werkstatt', label: 'Werkstatt', area: 'D', status: 'alt', legacy: 'werkstatt', note: 'Annahme, Aufträge, Kostenvoranschlag, Checklisten, Preisliste' },
  { id: 'fitting', label: 'Bikefitting', area: 'E', status: 'alt', legacy: 'sitzung', note: 'Wird als letztes übertragen, Ablauf bleibt gleich' },
  { id: 'verkauf', label: 'Verkauf', area: 'F', status: 'alt', legacy: 'rechnungen', note: 'Angebote und Rechnungen vorhanden. Aufträge, Rabatte, Retouren fehlen' },
  { id: 'lager', label: 'Warenwirtschaft', area: 'G', status: 'alt', legacy: 'lager', note: 'Lieferantenbestellung, Scanner, Seriennummern fehlen' },
  { id: 'organisation', label: 'Organisation', area: 'H', status: 'alt', legacy: 'team', note: 'Urlaub, Schichten, interne Nachrichten fehlen' },
  { id: 'netzwerk', label: 'FYF-Netzwerk', area: 'I', status: 'alt', legacy: 'netz', note: 'Händlerverzeichnis, Börse, Anfragen' },
  { id: 'integrationen', label: 'Integrationen', area: 'J', status: 'fehlt', note: 'Lexware Office, sevDesk, DATEV, Kasse mit TSE, E-Mail' },
];

export const STATUS_TEXT: Record<ModStatus, string> = { neu: 'Neu umgesetzt', alt: 'Noch in der bisherigen App', fehlt: 'Fehlt noch' };
