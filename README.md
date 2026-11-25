# Atril

Panel de estudio para Mac: glosario, búsqueda, repaso y preguntas a Claude, siempre encima de la presentación.

## Instalar o actualizar

Abre **Terminal** y pega esta línea:

```bash
curl -fsSL https://raw.githubusercontent.com/JOYb0Y-1/atril/main/instalar.sh | bash
```

- Sirve para cualquier Mac con macOS 12 o posterior, con chip Apple o Intel.
- Baja la última versión, comprueba su huella (sha256), la copia a Aplicaciones y la abre. No usa `sudo`.
- Para actualizar, se pega la misma línea otra vez.

## El contenido

El contenido de estudio llega solo: Atril lo baja al abrirse y cada 30 minutos. Si editas tu `contenido.md`, Atril respeta tus cambios y deja de reemplazarlo.

## Claude

En Ajustes (⌘,) → Claude → «Mi API Key», pega tu clave de Anthropic. Lo que preguntes se cobra a tu cuenta. Sin clave funciona todo lo demás.

## Atajos

⌃⌥G muestra y esconde Atril · ⌘F busca · ⌘L alterna entre la ficha y Claude · ⌘, abre Ajustes.

## Descarga manual

El `.dmg` de cada versión está en [Releases](https://github.com/JOYb0Y-1/atril/releases). Bajado así, macOS pide permiso la primera vez: en macOS 15 o posterior, Ajustes del Sistema → Privacidad y seguridad → «Abrir igualmente»; en macOS 12 a 14, clic derecho sobre Atril → Abrir.
