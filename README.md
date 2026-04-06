# Void Vortex

Een arcade-game voor de iPhone die we met z'n tweeën hebben gebouwd (vader en zoon), met hulp van AI.

![Void Vortex](GravityWell/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png)

## Wat is het?

Void Vortex is een spel waarin je als ruimteschip rond een zwart gat draait. Je hebt twee knoppen: eentje om dichter naar het zwarte gat toe te vliegen, en eentje om er juist vandaan te gaan. Het zwarte gat trekt je constant naar binnen, dus je moet goed opletten. Ondertussen komen er steeds meer obstakels op je af: asteroïden, laserstralen, magnetische velden en meer.

Het spel heeft 8 levels die steeds moeilijker worden, 3 moeilijkheidsgraden, en je kunt power-ups oppakken zoals een schild of extra levens.

## Wat kan het allemaal?

- Je draait automatisch rond het zwarte gat en stuurt alleen hoe ver je er vandaan bent
- 8 levels met steeds nieuwe obstakels
- 6 soorten obstakels: asteroïden, orbiters, ringen, magnetische velden, vortexen en laserstralen
- Power-ups zoals een schild, slow-motion, extra levens en bonuspunten
- Alle geluidseffecten worden live door de app zelf gemaakt, er zijn geen opgenomen geluiden
- Je telefoon trilt als je ergens tegenaan botst
- Je highscore en beste tijd worden bewaard

## Waarmee is het gebouwd?

De app is geschreven in **Swift**, de programmeertaal van Apple. Voor het tekenen van de graphics gebruiken we **SwiftUI met Canvas**. De geluidseffecten worden gemaakt met **AVAudioEngine**, waarmee de app zelf geluid genereert. De game loop draait op 60 tot 120 fps via **CADisplayLink**.

We hebben geen externe libraries of frameworks gebruikt. Alles is gebouwd met de standaard tools van Apple.

De code is geschreven met hulp van **Claude**, een AI-assistent van Anthropic.

## Hoe zet je het op je iPhone?

1. Open `GravityWell.xcodeproj` in Xcode (op een Mac)
2. Sluit je iPhone aan of kies een simulator
3. Druk op Build & Run (Cmd+R)

Je hebt macOS met Xcode nodig, en een iPhone met iOS 17.0 of nieuwer.

## Hoe het is gemaakt

We begonnen met een simpel prototype als webpagina, om te kijken of het idee leuk was. Toen dat goed voelde, zijn we het gaan bouwen als echte iPhone-app. Het idee en alle creatieve keuzes kwamen van ons. De AI hielp met het schrijven van de code en het oplossen van problemen. Zo werkten we samen: wij bedachten wat we wilden, en de AI hielp om het werkend te krijgen.

## Licentie

Dit project is bedoeld voor persoonlijk en educatief gebruik.

