#!/usr/bin/env python3
"""
App Store Connect listing copy for the locales added in 1.0.2 (ko, es, de, fr, pt-BR).

Run:  python3 AppStore/build_listing.py        → writes AppStore/listing_new_locales.json and checks every limit.

ASC limits: name 30, subtitle 30, promotional text 170, keywords 100, description 4000, what's new 4000.
Rules this copy follows (see the China-AI rejection):
  - no "gpt" / "ChatGPT" / "OpenAI" anywhere, and no link to the developer domain; the Terms link is Apple's standard EULA;
  - the Privacy Policy lives in its own ASC field, not in the description.
"""
import json
import re
import sys
from pathlib import Path

EULA = "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"

L: dict[str, dict] = {}

# ───────────────────────────────── Korean ─────────────────────────────────
L["ko"] = dict(
    name="MarketAtlas: 주식 히트맵",
    subtitle="시가총액 순위 & 스크리너",
    promo="세계 최대 기업을 한눈에: 시가총액 순위, 국가·섹터 히트맵, 1996년까지 거슬러 올라가는 타임머신, 움직이는 순위 레이스.",
    keywords="기업,세계,섹터,순이익,매출,배당,투자,위젯,비교,주가,순위,증시,글로벌,재무,종목,PER",
    whatsNew="""• 기업 비교: 2~4개 기업을 나란히 놓고 성장률·시가총액 차트와 주요 수치를 비교
• 순위 레이스: 2000년부터 현재까지 세계 최대 기업들의 순위 변화를 시가총액, 순이익, 매출로 확인
• 국가별·섹터별 히트맵, 성과 리더보드, 1996년까지 거슬러 올라가는 타임머신
• 홈 화면·잠금 화면 위젯, 이미지로 공유
• 이제 9개 언어를 지원합니다: 영어, 일본어, 중국어 간체·번체, 한국어, 스페인어, 독일어, 프랑스어, 브라질 포르투갈어
• MarketAtlas Pro: 이전에 앱을 구매하신 분은 계속 무료로 모든 기능을 사용할 수 있습니다
• 속도와 안정성 개선""",
    description=f"""전 세계 주식시장을 한눈에.

MarketAtlas는 81개 국가·지역의 상장 기업 11,000개 이상을 시가총액, 순이익, 매출 등으로 순위 매기고, 숫자를 히트맵과 순위, 움직이는 레이스로 바꿔 몇 초 만에 읽을 수 있게 해줍니다.

히트맵
모든 국가와 섹터를 한 화면에. 타일 크기는 시가총액, 색은 연초 이후·1년·3년·5년 동안의 변동입니다. 타일을 탭하면 해당 지역·섹터의 최대 기업으로 들어갑니다.

순위 레이스
2000년부터 현재까지 세계 최대 기업들이 서로 추월하는 모습을 확인하세요. 시가총액, 순이익, 매출로 전 세계, 특정 국가·지역 또는 특정 섹터를 겨룰 수 있습니다. 재생 중에도 일시정지, 이동, 속도 변경이 가능합니다.

타임머신
1996년까지 거슬러 올라가 원하는 달을 고르면 그때 가장 컸던 기업과 오늘의 순위를 볼 수 있습니다.

기업 비교
2~4개 기업을 나란히 놓고 성장률 또는 시가총액 차트와 주요 수치 표로 비교하세요. 각 행에서 가장 좋은 값이 강조됩니다.

성과 리더보드
연초 이후, 1·3·5·10년 동안, 또는 사상 최고가 대비 가장 많이 오르고 내린 기업을 보여줍니다.

스크리너 및 필터
11,000개 이상의 기업을 시가총액, 순이익, 매출, 직원 수, PER, 배당 수익률, 영업이익률, 부채, 현금 등으로 정렬하고 필터링하세요. 국가·지역과 섹터로 좁히거나 이름·티커로 검색할 수 있습니다.

기업 페이지
모든 기업의 가격·시가총액 추이, 연간 순이익·매출·현금, 그리고 다양한 재무 지표를 제공합니다.

AI 채팅
"시가총액 상위 10개", "두 기업 비교", "매출 추이"처럼 일상 언어로 물어보세요. 입력하거나 말로 질문할 수 있습니다.

위젯 및 공유
가장 큰 기업을 홈 화면이나 잠금 화면에 두세요. 히트맵, 순위, 기업 페이지를 깔끔한 이미지로 공유할 수 있습니다.

동기화되는 즐겨찾기
Apple 또는 Google로 로그인하면 즐겨찾기를 모든 기기에서 사용할 수 있습니다.

내 언어로
영어, 일본어, 중국어 간체·번체, 한국어, 스페인어, 독일어, 프랑스어, 브라질 포르투갈어.

MARKETATLAS PRO
MarketAtlas Pro로 모든 기능을 사용할 수 있습니다. 월간, 분기별, 연간 중에서 선택하거나(신규 구독자는 7일 무료 체험) 평생 이용권을 한 번에 구매할 수 있습니다. 구독형 앱이 되기 전에 MarketAtlas를 구매하신 분은 계속 무료로 모든 기능을 사용하실 수 있습니다.

결제 금액은 구매 확인 시 또는 무료 체험이 끝날 때 Apple 계정으로 청구됩니다. 현재 구독 기간이 끝나기 최소 24시간 전에 해지하지 않으면 구독은 자동으로 갱신되며, 갱신 비용은 기간 종료 전 24시간 이내에 청구됩니다. 설정 > Apple 계정 > 구독에서 언제든 관리하거나 해지할 수 있습니다. 무료 체험 기간 중 사용하지 않은 부분은 구독 구매 시 소멸됩니다.

이용약관: {EULA}

MarketAtlas는 정보 제공만을 목적으로 하며 투자 조언이 아닙니다. 데이터는 실시간이 아닙니다.""",
)

# ───────────────────────────────── Spanish ────────────────────────────────
L["es-ES"] = dict(
    name="MarketAtlas: Mapa de calor",
    subtitle="Ranking de capitalización",
    promo="Las mayores empresas del mundo de un vistazo: ranking por capitalización, mapas de calor por país y sector, máquina del tiempo hasta 1996 y carrera animada.",
    keywords="empresas,mayores,sector,beneficios,ingresos,dividendos,inversión,widget,comparar,bolsa,acciones,PER",
    whatsNew="""• Comparar empresas: de dos a cuatro empresas lado a lado, con gráfico de crecimiento o de capitalización y tabla de cifras clave
• Carrera de clasificación: mira cómo las mayores empresas se adelantan desde 2000 hasta hoy, por capitalización, beneficios o ingresos
• Mapas de calor por país y sector, rankings de rendimiento y una máquina del tiempo hasta 1996
• Widgets para la pantalla de inicio y de bloqueo, y compartir como imagen
• Ahora en 9 idiomas: inglés, japonés, chino simplificado y tradicional, coreano, español, alemán, francés y portugués de Brasil
• MarketAtlas Pro: quien ya compró la app conserva el acceso completo gratis
• Mejoras de velocidad y fiabilidad""",
    description=f"""Todo el mercado bursátil de un vistazo.

MarketAtlas clasifica más de 11.000 empresas cotizadas de 81 países y regiones por capitalización, beneficios, ingresos y más, y convierte las cifras en mapas de calor, rankings y una carrera animada que se leen en segundos.

MAPAS DE CALOR
Todos los países y todos los sectores en una pantalla. El tamaño del bloque es la capitalización y el color, la variación en lo que va de año, a 1, 3 o 5 años. Toca un bloque para ver sus mayores empresas.

CARRERA DE CLASIFICACIÓN
Mira cómo las mayores empresas del mundo se adelantan unas a otras desde 2000 hasta hoy. Compite por capitalización, beneficios o ingresos, en todo el mundo, en un país o región, o en un sector. Pausa, avanza y cambia la velocidad mientras se reproduce.

MÁQUINA DEL TIEMPO
Elige cualquier mes desde 1996 y descubre qué empresas eran las mayores entonces y dónde están hoy.

COMPARAR EMPRESAS
Pon de dos a cuatro empresas lado a lado: un gráfico de crecimiento o de capitalización y una tabla de cifras clave, con el mejor valor de cada fila resaltado.

RANKINGS DE RENDIMIENTO
Las que más suben y más bajan en lo que va de año, a 1, 3, 5 y 10 años, o desde su máximo histórico.

FILTROS
Ordena y filtra más de 11.000 empresas por capitalización, beneficios, ingresos, empleados, PER, rentabilidad por dividendo, margen operativo, deuda, efectivo y más. Acota por país o región y por sector, o busca por nombre o ticker.

PÁGINAS DE EMPRESA
Historial de precio y capitalización, beneficios anuales, ingresos y efectivo, y un conjunto completo de métricas financieras de cada empresa.

CHAT CON IA
Pregunta con tus palabras: «Las 10 mayores por capitalización», «Comparar dos empresas», «Historial de ingresos». Escribe o dicta tu pregunta.

WIDGETS Y COMPARTIR
Pon las mayores empresas en tu pantalla de inicio o de bloqueo. Comparte cualquier mapa de calor, ranking o página de empresa como una imagen limpia.

FAVORITOS QUE SE SINCRONIZAN
Inicia sesión con Apple o Google para tener tus favoritos en todos tus dispositivos.

EN TU IDIOMA
Inglés, japonés, chino simplificado y tradicional, coreano, español, alemán, francés y portugués de Brasil.

MARKETATLAS PRO
MarketAtlas Pro lo desbloquea todo. Elige mensual, trimestral o anual (los nuevos suscriptores empiezan con 7 días de prueba gratis) o cómpralo una sola vez de por vida. Quienes compraron MarketAtlas antes de que fuera una app de suscripción conservan el acceso completo gratis.

El pago se carga a tu cuenta de Apple al confirmar la compra o cuando termine la prueba gratuita. Las suscripciones se renuevan automáticamente salvo que se cancelen al menos 24 horas antes de que acabe el periodo en curso, y se cobra la renovación en las 24 horas previas al final del periodo. Gestiona o cancela cuando quieras en Ajustes > Cuenta de Apple > Suscripciones. La parte no usada de una prueba gratuita se pierde al comprar una suscripción.

Condiciones de uso: {EULA}

MarketAtlas solo ofrece información. No es asesoramiento de inversión y los datos no son en tiempo real.""",
)

# ───────────────────────────────── German ─────────────────────────────────
L["de-DE"] = dict(
    name="MarketAtlas: Börsen-Heatmap",
    subtitle="Marktkapitalisierung & Filter",
    promo="Die größten Unternehmen der Welt auf einen Blick: Ranking nach Marktkapitalisierung, Heatmaps nach Land und Sektor, Zeitmaschine bis 1996 und animiertes Ranking-Rennen.",
    keywords="Unternehmen,größte,Welt,Sektor,Gewinn,Umsatz,Dividende,Investieren,Widget,Vergleich,Aktien,Börse,KGV",
    whatsNew="""• Unternehmen vergleichen: zwei bis vier Unternehmen nebeneinander, mit Wachstums- oder Marktkapitalisierungs-Chart und Tabelle der Kennzahlen
• Ranking-Rennen: sieh, wie die größten Unternehmen sich von 2000 bis heute überholen, nach Marktkapitalisierung, Gewinn oder Umsatz
• Heatmaps nach Land und Sektor, Performance-Ranglisten und eine Zeitmaschine bis 1996
• Widgets für Home- und Sperrbildschirm, Teilen als Bild
• Jetzt in 9 Sprachen: Englisch, Japanisch, Chinesisch (vereinfacht und traditionell), Koreanisch, Spanisch, Deutsch, Französisch und brasilianisches Portugiesisch
• MarketAtlas Pro: Wer die App schon gekauft hat, behält den vollen Zugriff kostenlos
• Verbesserungen bei Geschwindigkeit und Zuverlässigkeit""",
    description=f"""Den ganzen Aktienmarkt auf einen Blick.

MarketAtlas ordnet über 11.000 börsennotierte Unternehmen in 81 Ländern und Regionen nach Marktkapitalisierung, Gewinn, Umsatz und mehr und macht aus den Zahlen Heatmaps, Rankings und ein animiertes Rennen, die du in Sekunden lesen kannst.

HEATMAPS
Jedes Land und jeder Sektor auf einem Bildschirm. Die Kachelgröße ist die Marktkapitalisierung, die Farbe die Veränderung seit Jahresbeginn, über 1, 3 oder 5 Jahre. Tippe auf eine Kachel, um zu den größten Unternehmen zu gelangen.

RANKING-RENNEN
Sieh zu, wie die größten Unternehmen der Welt sich von 2000 bis heute überholen. Nach Marktkapitalisierung, Gewinn oder Umsatz, weltweit, für ein Land oder eine Region oder einen Sektor. Während des Abspielens kannst du pausieren, vor- und zurückspulen und die Geschwindigkeit ändern.

ZEITMASCHINE
Wähle einen beliebigen Monat bis zurück ins Jahr 1996 und sieh, welche Unternehmen damals die größten waren und wo sie heute stehen.

UNTERNEHMEN VERGLEICHEN
Stelle zwei bis vier Unternehmen nebeneinander: ein Wachstums- oder Marktkapitalisierungs-Chart plus eine Tabelle mit Kennzahlen, in der der beste Wert jeder Zeile hervorgehoben ist.

PERFORMANCE-RANGLISTEN
Die größten Gewinner und Verlierer seit Jahresbeginn, über 1, 3, 5 und 10 Jahre oder gemessen am Allzeithoch.

SCREENER UND FILTER
Sortiere und filtere über 11.000 Unternehmen nach Marktkapitalisierung, Gewinn, Umsatz, Mitarbeitern, KGV, Dividendenrendite, operativer Marge, Schulden, Barmitteln und mehr. Grenze nach Land oder Region und Sektor ein oder suche nach Name oder Ticker.

UNTERNEHMENSSEITEN
Kurs- und Marktkapitalisierungsverlauf, Jahresgewinn, Umsatz und Barmittel sowie ein vollständiger Satz an Finanzkennzahlen für jedes Unternehmen.

KI-CHAT
Frage in normaler Sprache: „Top 10 nach Marktkapitalisierung“, „Zwei Unternehmen vergleichen“, „Umsatzentwicklung“. Tippe deine Frage oder diktiere sie.

WIDGETS UND TEILEN
Bringe die größten Unternehmen auf Home- oder Sperrbildschirm. Teile jede Heatmap, jedes Ranking und jede Unternehmensseite als saubere Grafik.

FAVORITEN MIT SYNC
Melde dich mit Apple oder Google an, um deine Favoriten auf jedem Gerät zu haben.

IN DEINER SPRACHE
Englisch, Japanisch, Chinesisch (vereinfacht und traditionell), Koreanisch, Spanisch, Deutsch, Französisch und brasilianisches Portugiesisch.

MARKETATLAS PRO
MarketAtlas Pro schaltet alles frei. Wähle monatlich, vierteljährlich oder jährlich (neue Abonnenten starten mit 7 Tagen kostenlos) oder kaufe es einmalig als lebenslangen Zugang. Wer MarketAtlas gekauft hat, bevor es zur Abo-App wurde, behält den vollen Zugriff kostenlos.

Die Zahlung wird bei Kaufbestätigung bzw. nach Ablauf der kostenlosen Testphase von deinem Apple-Account abgebucht. Abonnements verlängern sich automatisch, sofern sie nicht mindestens 24 Stunden vor Ende des laufenden Zeitraums gekündigt werden; die Verlängerung wird innerhalb von 24 Stunden vor Ende des Zeitraums berechnet. Verwalte oder kündige jederzeit unter Einstellungen > Apple-Account > Abonnements. Ein nicht genutzter Teil der kostenlosen Testphase verfällt, sobald du ein Abonnement abschließt.

Nutzungsbedingungen: {EULA}

MarketAtlas dient nur der Information. Es ist keine Anlageberatung, und die Daten sind nicht in Echtzeit.""",
)

# ───────────────────────────────── French ─────────────────────────────────
L["fr-FR"] = dict(
    name="MarketAtlas : Carte boursière",
    subtitle="Capitalisations & filtres",
    promo="Les géants du monde en un coup d’œil : classement par capitalisation, cartes thermiques par pays et secteur, remontée dans le temps jusqu’en 1996 et course animée.",
    keywords="entreprises,secteur,bénéfices,chiffre d’affaires,dividende,investir,widget,comparer,bourse,actions",
    whatsNew="""• Comparer des entreprises : de deux à quatre entreprises côte à côte, avec graphique de croissance ou de capitalisation et tableau des chiffres clés
• Course au classement : regardez les plus grandes entreprises se dépasser de 2000 à aujourd’hui, par capitalisation, bénéfices ou chiffre d’affaires
• Cartes thermiques par pays et secteur, classements de performance et machine à remonter le temps jusqu’en 1996
• Widgets pour l’écran d’accueil et l’écran verrouillé, partage en image
• Désormais en 9 langues : anglais, japonais, chinois simplifié et traditionnel, coréen, espagnol, allemand, français et portugais du Brésil
• MarketAtlas Pro : si vous aviez déjà acheté l’app, vous gardez l’accès complet gratuitement
• Améliorations de vitesse et de fiabilité""",
    description=f"""Tout le marché boursier en un coup d’œil.

MarketAtlas classe plus de 11 000 entreprises cotées dans 81 pays et régions par capitalisation, bénéfices, chiffre d’affaires et plus encore, puis transforme les chiffres en cartes thermiques, classements et course animée que vous lisez en quelques secondes.

CARTES THERMIQUES
Tous les pays et tous les secteurs sur un seul écran. La taille de la tuile est la capitalisation, la couleur la variation depuis le début de l’année, sur 1, 3 ou 5 ans. Touchez une tuile pour voir ses plus grandes entreprises.

COURSE AU CLASSEMENT
Regardez les plus grandes entreprises du monde se dépasser de 2000 à aujourd’hui. Courez par capitalisation, bénéfices ou chiffre d’affaires, pour le monde entier, un pays ou une région, ou un secteur. Pause, avance et vitesse réglables pendant la lecture.

MACHINE À REMONTER LE TEMPS
Choisissez n’importe quel mois depuis 1996 et voyez quelles entreprises étaient les plus grandes à l’époque, et où elles en sont aujourd’hui.

COMPARER DES ENTREPRISES
Placez deux à quatre entreprises côte à côte : un graphique de croissance ou de capitalisation et un tableau des chiffres clés, avec la meilleure valeur de chaque ligne mise en avant.

CLASSEMENTS DE PERFORMANCE
Les meilleures et les pires performances depuis le début de l’année, sur 1, 3, 5 et 10 ans, ou depuis leur plus haut historique.

FILTRES
Triez et filtrez plus de 11 000 entreprises par capitalisation, bénéfices, chiffre d’affaires, effectifs, PER, rendement du dividende, marge opérationnelle, dette, trésorerie et plus. Affinez par pays ou région et par secteur, ou cherchez un nom ou un ticker.

PAGES D’ENTREPRISE
Historique des prix et de la capitalisation, bénéfices annuels, chiffre d’affaires et trésorerie, et un ensemble complet d’indicateurs financiers pour chaque entreprise.

CHAT IA
Posez vos questions simplement : « Top 10 par capitalisation », « Comparer deux entreprises », « Historique du chiffre d’affaires ». Écrivez ou dictez.

WIDGETS ET PARTAGE
Affichez les plus grandes entreprises sur votre écran d’accueil ou de verrouillage. Partagez toute carte thermique, tout classement ou toute page d’entreprise en image.

FAVORIS SYNCHRONISÉS
Connectez-vous avec Apple ou Google pour retrouver vos favoris sur tous vos appareils.

DANS VOTRE LANGUE
Anglais, japonais, chinois simplifié et traditionnel, coréen, espagnol, allemand, français et portugais du Brésil.

MARKETATLAS PRO
MarketAtlas Pro débloque tout. Choisissez mensuel, trimestriel ou annuel (les nouveaux abonnés commencent par 7 jours d’essai gratuit) ou achetez-le une seule fois, à vie. Si vous avez acheté MarketAtlas avant qu’elle ne devienne une app par abonnement, vous gardez l’accès complet gratuitement.

Le paiement est débité de votre compte Apple à la confirmation de l’achat ou à la fin de l’essai gratuit. Les abonnements se renouvellent automatiquement sauf s’ils sont résiliés au moins 24 heures avant la fin de la période en cours, et le renouvellement est facturé dans les 24 heures précédant la fin de la période. Gérez ou résiliez à tout moment dans Réglages > Compte Apple > Abonnements. La partie non utilisée d’un essai gratuit est perdue lorsque vous souscrivez un abonnement.

Conditions d’utilisation : {EULA}

MarketAtlas fournit uniquement des informations. Ce n’est pas un conseil en investissement, et les données ne sont pas en temps réel.""",
)

# ───────────────────────────── Portuguese (Brazil) ────────────────────────
L["pt-BR"] = dict(
    name="MarketAtlas: Mapa de Ações",
    subtitle="Ranking de valor de mercado",
    promo="As maiores empresas do mundo num relance: ranking por valor de mercado, mapas de calor por país e setor, máquina do tempo até 1996 e uma corrida de ranking animada.",
    keywords="empresas,maiores,mundo,setor,lucro,receita,dividendos,investir,widget,comparar,bolsa,ações,P/L",
    whatsNew="""• Comparar empresas: de duas a quatro empresas lado a lado, com gráfico de crescimento ou de valor de mercado e tabela de números-chave
• Corrida de ranking: veja as maiores empresas se ultrapassando de 2000 até hoje, por valor de mercado, lucro ou receita
• Mapas de calor por país e setor, rankings de desempenho e uma máquina do tempo até 1996
• Widgets para a Tela de Início e a Tela Bloqueada, compartilhamento como imagem
• Agora em 9 idiomas: inglês, japonês, chinês simplificado e tradicional, coreano, espanhol, alemão, francês e português do Brasil
• MarketAtlas Pro: quem já comprou o app continua com acesso completo, de graça
• Melhorias de velocidade e confiabilidade""",
    description=f"""O mercado de ações inteiro num relance.

O MarketAtlas classifica mais de 11.000 empresas listadas em 81 países e regiões por valor de mercado, lucro, receita e mais, e transforma os números em mapas de calor, rankings e uma corrida animada que você lê em segundos.

MAPAS DE CALOR
Todos os países e todos os setores em uma tela. O tamanho do bloco é o valor de mercado e a cor, a variação no ano, em 1, 3 ou 5 anos. Toque em um bloco para ver as maiores empresas dele.

CORRIDA DE RANKING
Veja as maiores empresas do mundo se ultrapassando de 2000 até hoje. Corra por valor de mercado, lucro ou receita, com o mundo todo, um país ou região, ou um setor. Pause, avance e mude a velocidade durante a reprodução.

MÁQUINA DO TEMPO
Escolha qualquer mês desde 1996 e veja quais eram as maiores empresas na época e onde estão hoje.

COMPARAR EMPRESAS
Coloque de duas a quatro empresas lado a lado: um gráfico de crescimento ou de valor de mercado e uma tabela de números-chave, com o melhor valor de cada linha em destaque.

RANKINGS DE DESEMPENHO
As maiores altas e quedas no ano, em 1, 3, 5 e 10 anos, ou desde a máxima histórica.

FILTROS
Ordene e filtre mais de 11.000 empresas por valor de mercado, lucro, receita, funcionários, P/L, dividend yield, margem operacional, dívida, caixa e mais. Restrinja por país ou região e por setor, ou busque por nome ou ticker.

PÁGINAS DE EMPRESA
Histórico de preço e valor de mercado, lucro anual, receita e caixa, e um conjunto completo de indicadores financeiros de cada empresa.

CHAT COM IA
Pergunte com suas palavras: "As 10 maiores por valor de mercado", "Comparar duas empresas", "Histórico de receita". Digite ou dite a pergunta.

WIDGETS E COMPARTILHAMENTO
Coloque as maiores empresas na Tela de Início ou na Tela Bloqueada. Compartilhe qualquer mapa de calor, ranking ou página de empresa como uma imagem limpa.

FAVORITOS QUE SINCRONIZAM
Entre com Apple ou Google para ter seus favoritos em todos os dispositivos.

NO SEU IDIOMA
Inglês, japonês, chinês simplificado e tradicional, coreano, espanhol, alemão, francês e português do Brasil.

MARKETATLAS PRO
O MarketAtlas Pro libera tudo. Escolha mensal, trimestral ou anual (novos assinantes começam com 7 dias grátis) ou compre uma única vez, para sempre. Quem comprou o MarketAtlas antes de ele virar um app por assinatura continua com acesso completo, de graça.

O pagamento é cobrado na sua conta Apple na confirmação da compra ou quando o período grátis terminar. As assinaturas são renovadas automaticamente, a menos que sejam canceladas pelo menos 24 horas antes do fim do período atual, e a renovação é cobrada nas 24 horas anteriores ao fim do período. Gerencie ou cancele quando quiser em Ajustes > Conta Apple > Assinaturas. A parte não usada do período grátis é perdida quando você assina.

Termos de Uso: {EULA}

O MarketAtlas oferece apenas informações. Não é recomendação de investimento, e os dados não são em tempo real.""",
)

LIMITS = dict(name=30, subtitle=30, promo=170, keywords=100, whatsNew=4000, description=4000)
BANNED = re.compile(r"gpt|openai|appdevgpt", re.I)


def check() -> int:
    problems = 0
    for loc, f in L.items():
        for key, limit in LIMITS.items():
            n = len(f[key])
            flag = "OK " if n <= limit else "TOO LONG"
            if n > limit:
                problems += 1
            print(f"{loc:6} {key:12} {n:5}/{limit:<5} {flag}")
        if any(BANNED.search(v) for v in f.values()):
            print(f"{loc:6} BANNED WORD FOUND")
            problems += 1
        if "appdevgpt" in f["description"] or EULA not in f["description"]:
            print(f"{loc:6} description must link Apple's EULA only")
            problems += 1
        # keywords: comma separated, no space after commas, no duplicates
        kw = f["keywords"].split(",")
        if len(kw) != len({k.lower() for k in kw}):
            print(f"{loc:6} duplicate keyword")
            problems += 1
    return problems


if __name__ == "__main__":
    bad = check()
    out = Path(__file__).with_name("listing_new_locales.json")
    out.write_text(json.dumps(L, ensure_ascii=False, indent=2) + "\n")
    print(f"\nwrote {out.name} ({len(L)} locales); problems: {bad}")
    sys.exit(1 if bad else 0)
