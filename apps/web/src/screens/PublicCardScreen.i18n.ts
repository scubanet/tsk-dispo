/**
 * Translations for the public card page (PublicCardScreen).
 * Only UI chrome is translated — card data (title, specialties, owner name)
 * stays in the source language (DE).
 */

export type Lang = 'de' | 'en' | 'fr'

export const SUPPORTED_LANGS: readonly Lang[] = ['de', 'en', 'fr'] as const

export interface Translations {
  addToContacts:      string
  callMe:             string
  emailMe:            string
  whatsapp:           string
  leadFormTitle:      string
  leadFormFirstName:  string
  leadFormLastName:   string
  leadFormEmail:      string
  leadFormPhone:      string
  leadFormTopic:      string
  leadFormMessage:    string
  leadFormSubmit:     string
  leadFormSending:    string
  leadFormSuccess:    string
  leadFormError:      string
  notFoundTitle:      string
  notFoundMessage:    string
  languageLabel:      string
  loading:            string
  errorLoading:       string
  speaks:             string
  statDives:          string
  statDivingSince:    string
  statLevel:          string
  connect:            string
  createdWith:        string
}

export const translations: Record<Lang, Translations> = {
  de: {
    addToContacts:      'Als Kontakt speichern',
    callMe:             'Anrufen',
    emailMe:            'E-Mail senden',
    whatsapp:           'WhatsApp',
    leadFormTitle:      'Anfrage schicken',
    leadFormFirstName:  'Vorname',
    leadFormLastName:   'Nachname',
    leadFormEmail:      'E-Mail',
    leadFormPhone:      'Telefon',
    leadFormTopic:      'Worum gehts?',
    leadFormMessage:    'Nachricht',
    leadFormSubmit:     'Senden',
    leadFormSending:    'Sende...',
    leadFormSuccess:    'Danke — ich melde mich!',
    leadFormError:      'Konnte nicht senden — bitte später nochmal versuchen.',
    notFoundTitle:      'Karte nicht gefunden',
    notFoundMessage:    'Diese Karte existiert nicht (mehr).',
    languageLabel:      'Sprache',
    loading:            'Lade Karte …',
    errorLoading:       'Karte konnte nicht geladen werden.',
    speaks:             'Spricht',
    statDives:          'Tauchgänge',
    statDivingSince:    'Taucht seit',
    statLevel:          'Level',
    connect:            'Verbinden',
    createdWith:        'Erstellt mit AtollCard',
  },
  en: {
    addToContacts:      'Save as contact',
    callMe:             'Call',
    emailMe:            'Email',
    whatsapp:           'WhatsApp',
    leadFormTitle:      'Get in touch',
    leadFormFirstName:  'First name',
    leadFormLastName:   'Last name',
    leadFormEmail:      'Email',
    leadFormPhone:      'Phone',
    leadFormTopic:      'About what?',
    leadFormMessage:    'Message',
    leadFormSubmit:     'Send',
    leadFormSending:    'Sending...',
    leadFormSuccess:    'Thanks — I will reach out!',
    leadFormError:      'Could not send — please try again later.',
    notFoundTitle:      'Card not found',
    notFoundMessage:    'This card does not exist (anymore).',
    languageLabel:      'Language',
    loading:            'Loading card …',
    errorLoading:       'Could not load the card.',
    speaks:             'Speaks',
    statDives:          'Dives',
    statDivingSince:    'Diving since',
    statLevel:          'Level',
    connect:            'Connect',
    createdWith:        'Made with AtollCard',
  },
  fr: {
    addToContacts:      'Enregistrer comme contact',
    callMe:             'Appeler',
    emailMe:            'E-mail',
    whatsapp:           'WhatsApp',
    leadFormTitle:      'Prendre contact',
    leadFormFirstName:  'Prénom',
    leadFormLastName:   'Nom',
    leadFormEmail:      'E-mail',
    leadFormPhone:      'Téléphone',
    leadFormTopic:      'À quel sujet ?',
    leadFormMessage:    'Message',
    leadFormSubmit:     'Envoyer',
    leadFormSending:    'Envoi...',
    leadFormSuccess:    'Merci — je vous contacte !',
    leadFormError:      "Impossible d'envoyer — veuillez réessayer plus tard.",
    notFoundTitle:      'Carte introuvable',
    notFoundMessage:    "Cette carte n'existe pas (plus).",
    languageLabel:      'Langue',
    loading:            'Chargement de la carte …',
    errorLoading:       'Impossible de charger la carte.',
    speaks:             'Parle',
    statDives:          'Plongées',
    statDivingSince:    'Plonge depuis',
    statLevel:          'Niveau',
    connect:            'Contact',
    createdWith:        'Créé avec AtollCard',
  },
}

/**
 * Resolve the page language from URL params + browser Accept-Language.
 * Priority: ?lang= param > navigator.language > 'de' fallback.
 */
export function resolveLanguage(searchParams: URLSearchParams): Lang {
  const param = searchParams.get('lang')?.toLowerCase()
  if (param === 'de' || param === 'en' || param === 'fr') return param

  const accept = navigator.language.split('-')[0].toLowerCase()
  if (accept === 'en' || accept === 'fr') return accept

  return 'de'
}
