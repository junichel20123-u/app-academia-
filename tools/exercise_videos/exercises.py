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
        "barbell bent over row",
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
    ("cadeira-flexora", "Cadeira flexora", "leg curl machine"),
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
        "barbell overhead press",
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
    ("burpee", "Burpee", "burpee exercise"),
    ("kettlebell-swing", "Kettlebell swing", "kettlebell swing"),
    ("corrida-na-esteira", "Corrida na esteira", "treadmill running"),
    # exercisesAddedInSchemaV4
    ("supino-maquina", "Supino máquina", "chest press machine"),
    (
        "peck-deck-voador-maquina",
        "Peck deck (voador máquina)",
        "pec deck machine fly",
    ),
    ("remada-maquina", "Remada máquina", "seated row machine"),
    (
        "puxada-supinada-na-maquina",
        "Puxada supinada na máquina",
        "underhand lat pulldown machine",
    ),
    ("cadeira-adutora", "Cadeira adutora", "hip adductor machine"),
    ("cadeira-abdutora", "Cadeira abdutora", "hip abductor machine"),
    (
        "panturrilha-em-pe-na-maquina",
        "Panturrilha em pé na máquina",
        "standing calf raise machine",
    ),
    (
        "agachamento-hack-na-maquina",
        "Agachamento hack na máquina",
        "hack squat machine",
    ),
    ("desenvolvimento-maquina", "Desenvolvimento máquina", "shoulder press machine"),
    ("triceps-maquina", "Tríceps máquina", "tricep extension machine"),
    ("rosca-scott-na-maquina", "Rosca scott na máquina", "preacher curl machine"),
    ("abdominal-maquina", "Abdominal máquina", "ab crunch machine"),
    ("bicicleta-ergometrica", "Bicicleta ergométrica", "stationary bike cycling"),
    ("eliptico", "Elíptico", "elliptical machine cardio"),
    ("remo-ergometrico", "Remo ergométrico", "rowing machine cardio"),
    ("pular-corda", "Pular corda", "jump rope exercise"),
    # exercisesAddedInSchemaV5
    ("remada-baixa-na-polia", "Remada baixa na polia", "seated cable row"),
    ("elevacao-lateral-no-cabo", "Elevação lateral no cabo", "cable lateral raise"),
    ("face-pull-na-polia", "Face pull na polia", "cable face pull"),
    ("rosca-na-polia-baixa", "Rosca na polia baixa", "cable bicep curl"),
    (
        "triceps-frances-na-polia",
        "Tríceps francês na polia",
        "cable overhead tricep extension",
    ),
    ("abdominal-na-polia-alta", "Abdominal na polia alta", "cable crunch"),
    ("coice-no-cabo-gluteos", "Coice no cabo (glúteos)", "cable kickback glutes"),
    # exercisesAddedInSchemaV6
    ("abducao-de-quadril-na-polia", "Abdução de quadril na polia", "cable hip abduction"),
    ("aducao-de-quadril-na-polia", "Adução de quadril na polia", "cable hip adduction"),
    ("flexao-de-quadril-na-polia", "Flexão de quadril na polia", "cable hip flexion"),
    ("agachamento-na-polia", "Agachamento na polia", "cable squat"),
    ("stiff-na-polia", "Stiff na polia", "cable stiff leg deadlift"),
    ("woodchopper-na-polia", "Woodchopper na polia", "cable woodchopper"),
    (
        "prancha-lateral-com-puxada-na-polia",
        "Prancha lateral com puxada na polia",
        "side plank cable row",
    ),
    # exercisesAddedInSchemaV7
    ("elevacao-pelvica-na-maquina", "Elevação pélvica na máquina", "hip thrust machine"),
    (
        "panturrilha-sentada-na-maquina",
        "Panturrilha sentada na máquina",
        "seated calf raise machine",
    ),
    (
        "graviton-barra-fixa-paralelas-assistidas",
        "Graviton (barra fixa/paralelas assistidas)",
        "assisted pull up dip machine",
    ),
    ("abdominal-no-banco-declinado", "Abdominal no banco declinado", "decline bench sit up"),
    # exercisesAddedInSchemaV9
    ("polichinelo", "Polichinelo", "jumping jacks"),
    ("agachamento-com-peso-corporal", "Agachamento com peso corporal", "bodyweight squat"),
    ("afundo-alternado", "Afundo alternado", "alternating lunges bodyweight"),
    ("escalador", "Escalador", "mountain climbers exercise"),
    ("joelhos-altos", "Joelhos altos", "high knees exercise"),
    ("agachamento-com-salto", "Agachamento com salto", "jump squat"),
]
