"""The 68 exercises seeded in lib/core/database/seed/seed_exercises.dart,
paired with an English search query for stock-video sites (Pexels/Pixabay
are indexed almost entirely in English; the exercise names in the app are
PT-BR). `slug` matches exactly what `slugify()` produces for that exercise
name in the Flutter app (lib/core/utils/slugify.dart) — this is the key the
app will eventually use to look up a video for a given exercise, so it must
stay in sync if exercise names ever change.

Kept as a separate, plain-data module (no argparse/network here) so both
`search_and_download.py` and any future tooling can import it directly.
"""

EXERCISES = [
    # _v1Exercises
    ("supino-reto-com-barra", "Supino reto com barra", "barbell bench press"),
    (
        "supino-inclinado-com-halteres",
        "Supino inclinado com halteres",
        "incline dumbbell bench press",
    ),
    ("crucifixo-no-cabo", "Crucifixo no cabo", "cable fly chest exercise"),
    ("flexao-de-braco", "Flexão de braço", "push up exercise"),
    ("puxada-frontal", "Puxada frontal", "lat pulldown cable machine"),
    (
        "remada-curvada-com-barra",
        "Remada curvada com barra",
        "barbell bent over row back workout gym",
    ),
    (
        "remada-unilateral-com-halter",
        "Remada unilateral com halter",
        "single arm dumbbell row",
    ),
    ("barra-fixa", "Barra fixa", "pull up exercise"),
    ("agachamento-livre", "Agachamento livre", "barbell back squat"),
    ("leg-press", "Leg press", "leg press machine"),
    ("cadeira-extensora", "Cadeira extensora", "leg extension machine"),
    (
        "cadeira-flexora",
        "Cadeira flexora",
        "seated leg curl machine gym equipment",
    ),
    ("afundo-com-halteres", "Afundo com halteres", "dumbbell lunge"),
    ("levantamento-terra", "Levantamento terra", "barbell deadlift"),
    (
        "desenvolvimento-com-halteres",
        "Desenvolvimento com halteres",
        "dumbbell shoulder press",
    ),
    ("elevacao-lateral", "Elevação lateral", "dumbbell lateral raise"),
    ("elevacao-frontal", "Elevação frontal", "dumbbell front raise"),
    (
        "desenvolvimento-militar-com-barra",
        "Desenvolvimento militar com barra",
        "barbell military press shoulder workout gym",
    ),
    ("rosca-direta-com-barra", "Rosca direta com barra", "barbell bicep curl"),
    (
        "rosca-alternada-com-halteres",
        "Rosca alternada com halteres",
        "alternating dumbbell curl",
    ),
    (
        "triceps-corda-no-cabo",
        "Tríceps corda no cabo",
        "cable tricep pushdown rope",
    ),
    ("triceps-testa-com-barra", "Tríceps testa com barra", "barbell skull crusher"),
    ("prancha-abdominal", "Prancha abdominal", "plank exercise"),
    ("abdominal-supra", "Abdominal supra", "crunches exercise"),
    ("elevacao-de-pernas", "Elevação de pernas", "leg raise exercise"),
    ("burpee", "Burpee", "burpee workout fitness training"),
    ("kettlebell-swing", "Kettlebell swing", "kettlebell swing"),
    ("corrida-na-esteira", "Corrida na esteira", "treadmill running"),
    # exercisesAddedInSchemaV4
    ("supino-maquina", "Supino máquina", "chest press machine gym workout"),
    (
        "peck-deck-voador-maquina",
        "Peck deck (voador máquina)",
        "pec deck machine fly",
    ),
    ("remada-maquina", "Remada máquina", "seated row machine gym workout"),
    (
        "puxada-supinada-na-maquina",
        "Puxada supinada na máquina",
        "underhand grip lat pulldown machine gym",
    ),
    (
        "cadeira-adutora",
        "Cadeira adutora",
        "inner thigh adductor machine gym",
    ),
    (
        "cadeira-abdutora",
        "Cadeira abdutora",
        "outer thigh abductor machine gym",
    ),
    (
        "panturrilha-em-pe-na-maquina",
        "Panturrilha em pé na máquina",
        "standing calf raise machine gym workout",
    ),
    (
        "agachamento-hack-na-maquina",
        "Agachamento hack na máquina",
        "hack squat machine gym equipment",
    ),
    ("desenvolvimento-maquina", "Desenvolvimento máquina", "shoulder press machine"),
    ("triceps-maquina", "Tríceps máquina", "tricep extension machine gym workout"),
    ("rosca-scott-na-maquina", "Rosca scott na máquina", "preacher curl machine"),
    (
        "abdominal-maquina",
        "Abdominal máquina",
        "ab crunch machine gym workout",
    ),
    ("bicicleta-ergometrica", "Bicicleta ergométrica", "stationary bike cycling"),
    ("eliptico", "Elíptico", "elliptical machine cardio"),
    ("remo-ergometrico", "Remo ergométrico", "rowing machine cardio"),
    ("pular-corda", "Pular corda", "jump rope exercise"),
    # exercisesAddedInSchemaV5
    ("remada-baixa-na-polia", "Remada baixa na polia", "seated cable row"),
    ("elevacao-lateral-no-cabo", "Elevação lateral no cabo", "cable lateral raise shoulder exercise gym"),
    ("face-pull-na-polia", "Face pull na polia", "cable face pull exercise gym rope shoulder"),
    ("rosca-na-polia-baixa", "Rosca na polia baixa", "cable bicep curl"),
    (
        "triceps-frances-na-polia",
        "Tríceps francês na polia",
        "cable overhead tricep extension",
    ),
    (
        "abdominal-na-polia-alta",
        "Abdominal na polia alta",
        "kneeling cable crunch abs workout",
    ),
    ("coice-no-cabo-gluteos", "Coice no cabo (glúteos)", "cable kickback glutes"),
    # exercisesAddedInSchemaV6
    ("abducao-de-quadril-na-polia", "Abdução de quadril na polia", "cable hip abduction"),
    ("aducao-de-quadril-na-polia", "Adução de quadril na polia", "cable machine hip adduction exercise gym"),
    ("flexao-de-quadril-na-polia", "Flexão de quadril na polia", "cable machine hip flexor exercise gym"),
    (
        "agachamento-na-polia",
        "Agachamento na polia",
        "cable squat exercise gym workout",
    ),
    ("stiff-na-polia", "Stiff na polia", "cable machine stiff leg deadlift gym"),
    ("woodchopper-na-polia", "Woodchopper na polia", "cable machine woodchopper exercise gym"),
    (
        "prancha-lateral-com-puxada-na-polia",
        "Prancha lateral com puxada na polia",
        "side plank exercise core workout",
    ),
    # exercisesAddedInSchemaV7
    ("elevacao-pelvica-na-maquina", "Elevação pélvica na máquina", "hip thrust machine gym equipment glutes"),
    (
        "panturrilha-sentada-na-maquina",
        "Panturrilha sentada na máquina",
        "seated calf raise machine gym workout",
    ),
    (
        "graviton-barra-fixa-paralelas-assistidas",
        "Graviton (barra fixa/paralelas assistidas)",
        "assisted pull up machine gym equipment",
    ),
    ("abdominal-no-banco-declinado", "Abdominal no banco declinado", "decline bench sit up"),
    # exercisesAddedInSchemaV9
    ("polichinelo", "Polichinelo", "jumping jacks"),
    ("agachamento-com-peso-corporal", "Agachamento com peso corporal", "bodyweight squat"),
    ("afundo-alternado", "Afundo alternado", "alternating lunges bodyweight"),
    ("escalador", "Escalador", "mountain climbers exercise"),
    ("joelhos-altos", "Joelhos altos", "high knees exercise"),
    (
        "agachamento-com-salto",
        "Agachamento com salto",
        "jump squat workout fitness training",
    ),
]
