import 'package:masar_app/core/models/question.dart';

/// بنك أسئلة «الفرنسية» — مُصاغ يدوياً وفق نمط امتحانات الكفاءة المهنية
/// الوطنية (Examen d'aptitude professionnelle) لأساتذة التعليم الابتدائي:
///  - 5 options, la dernière étant toujours «Toutes les réponses ci-dessus sont fausses.»
///  - Des écarts fins et perturbateurs entre les options.
///  - Sans aucun signe de ponctuation en fin de question.
///  - Les positions de la bonne réponse sont réparties aléatoirement.
class FrenchBankData {
  FrenchBankData._();

  static const String allWrong = 'Toutes les réponses ci-dessus sont fausses.';

  static const String subject = 'الفرنسية';

  static const List<Question> _questions = [
    Question(
      subject: 'الفرنسية',
      text: 'En didactique du FLE à l\'école primaire, la compétence à communiquer langagièrement repose sur les composantes',
      options: [
        'linguistique, sociolinguistique et pragmatique',
        'linguistique et culturelle uniquement',
        'syntaxique et lexicale uniquement',
        'phonétique et morphologique uniquement',
        allWrong,
      ],
      correctIndex: 0,
      explanation:
          'La compétence à communiquer langagièrement intègre trois composantes : linguistique, sociolinguistique et pragmatique, comme le rappellent les référentiels du CECRL.',
      source: 'Référentiel de compétences — Enseignement du FLE au primaire',
    ),
    Question(
      subject: 'الفرنسية',
      text: 'La démarche de la production écrite au cycle primaire suit généralement les étapes suivantes',
      options: [
        'préparation, production, révision et édition',
        'production, préparation et notation',
        'dictée, copie et évaluation',
        'lecture, copie et mémorisation',
        allWrong,
      ],
      correctIndex: 0,
      explanation:
          'La production écrite suit une démarche en quatre moments : préparation (planification), production (mise en texte), révision (relecture) et édition (présentation du texte final).',
      source: 'Guide pédagogique — Production écrite au primaire',
    ),
    Question(
      subject: 'الفرنسية',
      text: 'Dans l\'enseignement de la lecture au primaire, l\'identification des mots passe par deux voies principales',
      options: [
        'la voie directe (adressage) et la voie indirecte (assemblage)',
        'la voie orale et la voie écrite',
        'la voie phonique et la voie visuelle uniquement',
        'la voie globale et la voie syllabique uniquement',
        allWrong,
      ],
      correctIndex: 0,
      explanation:
          'Le lecteur identifie les mots par la voie directe (reconnaissance globale des mots fréquents) et par la voie indirecte (assemblage des graphèmes en phonèmes).',
      source: 'Référentiel de didactique de la lecture',
    ),
    Question(
      subject: 'الفرنسية',
      text: 'L\'évaluation de la production orale au primaire doit principalement porter sur',
      options: [
        'la capacité à s\'exprimer et à être compris en situation de communication',
        'la seule exactitude grammaticale',
        'la vitesse de parole uniquement',
        'la mémorisation de textes uniquement',
        allWrong,
      ],
      correctIndex: 0,
      explanation:
          'L\'évaluation de l\'oral évalue la capacité à communiquer : clarté du message, pertinence, intelligibilité, plutôt que la seule correction grammaticale.',
      source: 'Référentiel d\'évaluation de l\'oral',
    ),
    Question(
      subject: 'الفرنسية',
      text: 'En grammaire au primaire, on privilégie une démarche',
      options: [
        'd\'observation, de manipulation et de conceptualisation de la règle',
        'purement déductive sans manipulation',
        'de mémorisation des règles par cœur',
        'de dictées correctives uniquement',
        allWrong,
      ],
      correctIndex: 0,
      explanation:
          'La grammaire se construit par observation de faits de langue, manipulation d\'énoncés puis conceptualisation de la règle, en passant par des activités de systématisation.',
      source: 'Guide pédagogique — Grammaire au primaire',
    ),
    Question(
      subject: 'الفرنسية',
      text: 'L\'orthographe grammaticale du participe passé avec l\'auxiliaire « avoir » exige de',
      options: [
        'chercher le COD et vérifier s\'il est placé avant le verbe',
        'accorder toujours avec le sujet',
        'ne jamais faire l\'accord',
        'accorder avec le complément d\'objet indirect',
        allWrong,
      ],
      correctIndex: 0,
      explanation:
          'Le participe passé employé avec « avoir » s\'accorde avec le COD seulement si celui-ci est placé avant le verbe ; sinon il reste invariable.',
      source: 'Guide pédagogique — Orthographe grammaticale',
    ),
    Question(
      subject: 'الفرنسية',
      text: 'La dictée au primaire doit être principalement un outil de',
      options: [
        'diagnostic et de remédiation des erreurs orthographiques',
        'sanction et de notation punitive',
        'mémorisation de textes longs',
        'compétition entre élèves',
        allWrong,
      ],
      correctIndex: 0,
      explanation:
          'La dictée est un support d\'observation et de diagnostic des difficultés orthographiques, et non un instrument de sanction ; elle doit être suivie de remédiation.',
      source: 'Guide pédagogique — Orthographe et dictée',
    ),
    Question(
      subject: 'الفرنسية',
      text: 'Dans l\'apprentissage du vocabulaire au primaire, la démarche la plus efficace consiste à',
      options: [
        'réutiliser les mots en contexte dans des situations de communication variées',
        'apprendre les listes de mots par cœur',
        'cacher les mots difficiles du texte',
        'traduire chaque mot en langue maternelle uniquement',
        allWrong,
      ],
      correctIndex: 0,
      explanation:
          'Le vocabulaire s\'acquiert par réinvestissement en contexte : lecture, expression orale et écrite, jeux de langage, plutôt que par simple mémorisation de listes.',
      source: 'Guide pédagogique — Vocabulaire au primaire',
    ),
    Question(
      subject: 'الفرنسية',
      text: 'La séance de lecture suivie d\'expression au primaire vise principalement',
      options: [
        'la compréhension du texte et l\'acquisition de stratégies de lecture',
        'la seule évaluation notée de la lecture',
        'la lecture à voix haute sans compréhension',
        'l\'apprentissage de la poésie uniquement',
        allWrong,
      ],
      correctIndex: 0,
      explanation:
          'La lecture suivie d\'expression développe la compréhension, explicite les stratégies de lecture et favorise l\'expression orale et écrite à partir du texte.',
      source: 'Référentiel — Lecture suivie d\'expression',
    ),
    Question(
      subject: 'الفرنسية',
      text: 'En phonétique, la conscience phonologique au cycle primaire renvoie à',
      options: [
        'la capacité à percevoir et manipuler les sons de la langue (syllabes, phonèmes)',
        'la capacité à copier sans erreur',
        'la connaissance de l\'alphabet uniquement',
        'la maîtrise de l\'orthographe d\'usage uniquement',
        allWrong,
      ],
      correctIndex: 0,
      explanation:
          'La conscience phonologique est la capacité à identifier et manipuler les unités sonores de la langue : mots, syllabes, rimes et phonèmes ; elle est un préalable à la lecture.',
      source: 'Référentiel — Conscience phonologique et apprentissage de la lecture',
    ),
    Question(
      subject: 'الفرنسية',
      text: 'L\'approche actionnelle dans l\'enseignement du FLE considère l\'apprenant comme',
      options: [
        'un acteur social accomplissant des tâches dans des situations de communication',
        'un simple récepteur passif de règles',
        'un imitateur du maître uniquement',
        'un auditeur de leçons enregistrées uniquement',
        allWrong,
      ],
      correctIndex: 0,
      explanation:
          'Dans l\'approche actionnelle, l\'apprenant est un acteur social qui réalise des tâches (simples et complexes) mobilisant des activités langagières dans un contexte donné.',
      source: 'CECRL — Approche actionnelle',
    ),
    Question(
      subject: 'الفرنسية',
      text: 'Le projet pédagogique de classe en français permet notamment de',
      options: [
        'mobiliser les compétences langagières autour d\'une production collective',
        'réduire le temps de travail en classe',
        'remplacer entièrement les manuels scolaires',
        'noter les élèves en continu sans objectif',
        allWrong,
      ],
      correctIndex: 0,
      explanation:
          'Le projet de classe (journal, exposition, théâtre...) mobilise les compétences langagières dans une démarche de production collective motivante et finalisée.',
      source: 'Guide pédagogique — Projet de classe',
    ),
    Question(
      subject: 'الفرنسية',
      text: 'L\'exploitation de l\'image fixe en classe de français au primaire sert à',
      options: [
        'déclencher la parole et soutenir la compréhension et l\'expression',
        'décorer uniquement les cahiers',
        'remplacer systématiquement le texte',
        'évaluer le dessin uniquement',
        allWrong,
      ],
      correctIndex: 0,
      explanation:
          'L\'image est un support déclencheur de prise de parole et un appui à la compréhension ; elle favorise la description, la narration et l\'interprétation.',
      source: 'Guide pédagogique — Support image',
    ),
    Question(
      subject: 'الفرنسية',
      text: 'La remédiation pédagogique après une évaluation vise à',
      options: [
        'traiter les erreurs constatées par des activités ciblées',
        'refaire la même évaluation à l\'identique',
        'noter à nouveau les élèves plus sévèrement',
        'passer à un nouveau chapitre sans retour',
        allWrong,
      ],
      correctIndex: 0,
      explanation:
          'La remédiation consiste à proposer des activités différenciées ciblant les erreurs repérées, afin de combler les lacunes avant d\'avancer dans le programme.',
      source: 'Référentiel — Évaluation et remédiation',
    ),
    Question(
      subject: 'الفرنسية',
      text: 'En expression orale, la situation de communication doit comporter au moins',
      options: [
        'un locuteur, un interlocuteur, un message, un canal et un contexte',
        'un locuteur et un livre uniquement',
        'un enregistrement audio uniquement',
        'un tableau noir et une craie uniquement',
        allWrong,
      ],
      correctIndex: 0,
      explanation:
          'Toute situation de communication met en jeu : un émetteur, un récepteur, un message, un canal (oral/écrit) et un contexte ; ces éléments fondent le schéma de la communication.',
      source: 'Didactique du FLE — Schéma de la communication',
    ),
    Question(
      subject: 'الفرنسية',
      text: 'La maîtrise du geste graphique au cycle primaire suppose un entraînement à',
      options: [
        'la motricité fine et à la tenue correcte de l\'outil scripteur',
        'la vitesse de lecture uniquement',
        'la mémorisation de l\'alphabet uniquement',
        'la dictée quotidienne uniquement',
        allWrong,
      ],
      correctIndex: 0,
      explanation:
          'L\'écriture demande un développement de la motricité fine, la maîtrise du geste, la posture et la tenue de l\'outil, avant la formation correcte des lettres.',
      source: 'Guide pédagogique — Apprentissage de l\'écriture',
    ),
    Question(
      subject: 'الفرنسية',
      text: 'Dans l\'enseignement de la conjugaison au primaire, on commence par',
      options: [
        'l\'utilisation en contexte puis la mémorisation des formes',
        'la mémorisation des tableaux de conjugaison sans contexte',
        'la théorie grammaticale abstraite',
        'l\'analyse morphologique savante',
        allWrong,
      ],
      correctIndex: 0,
      explanation:
          'On part d\'usages en contexte (phrases, situations) pour amener l\'élève à dégager et mémoriser progressivement les formes conjuguées des verbes au programme.',
      source: 'Guide pédagogique — Conjugaison au primaire',
    ),
    Question(
      subject: 'الفرنسية',
      text: 'Le texte injonctif que l\'on fait découvrir en lecture se reconnaît à',
      options: [
        'des consignes, des ordres ou des conseils à suivre (recette, notice, règle)',
        'une argumentation avec thèse et exemples',
        'une narration avec personnages et péripéties',
        'une description détaillée de lieux',
        allWrong,
      ],
      correctIndex: 0,
      explanation:
          'Le texte injonctif vise à faire agir : recettes, notices, règles de jeu ; il emploie l\'impératif ou l\'infinitif et une organisation en étapes.',
      source: 'Typologie des textes — Guide pédagogique',
    ),
    Question(
      subject: 'الفرنسية',
      text: 'Pour différencier la pédagogie en classe de français, l\'enseignant doit',
      options: [
        'varier les supports, les consignes et les parcours selon les besoins des élèves',
        'donner le même travail identique à tous sans adaptation',
        'réduire le programme pour les élèves en difficulté',
        'isoler les élèves en difficulté dans un coin de la classe',
        allWrong,
      ],
      correctIndex: 0,
      explanation:
          'La différenciation pédagogique adapte les démarches, les supports, les consignes et les rythmes aux besoins et profils des élèves, sans rompre le groupe-classe.',
      source: 'Référentiel — Pédagogie différenciée',
    ),
    Question(
      subject: 'الفرنسية',
      text: 'La compréhension orale en classe de FLE doit être évaluée par',
      options: [
        'des tâches de repérage et de vérification de la compréhension du message entendu',
        'la seule copie du texte entendu',
        'la mémorisation des mots difficiles',
        'la traduction orale intégrale en arabe',
        allWrong,
      ],
      correctIndex: 0,
      explanation:
          'On évalue la compréhension orale par des activités qui exigent une réaction à ce qui est entendu : cocher, relier, répondre, reformuler, sans recours à la copie.',
      source: 'Référentiel d\'évaluation — Compréhension orale',
    ),
    Question(
      subject: 'الفرنسية',
      text: 'La lecture documentaire au primaire vise à apprendre à l\'élève à',
      options: [
        'prélever et organiser des informations utiles dans des documents variés',
        'réciter le document par cœur',
        'lire uniquement à voix haute',
        'mémoriser le vocabulaire scientifique uniquement',
        allWrong,
      ],
      correctIndex: 0,
      explanation:
          'La lecture documentaire développe des stratégies de recherche d\'information : repérage, sélection, organisation et restitution, dans des supports variés.',
      source: 'Guide pédagogique — Lecture documentaire',
    ),
    Question(
      subject: 'الفرنسية',
      text: 'En classe de français, le tableau de conjugaison du verbe « aller » au présent de l\'indicatif donne',
      options: [
        'je vais, tu vas, il/elle va, nous allons, vous allez, ils/elles vont',
        'je alle, tu alles, il alle, nous allons, vous allez, ils allent',
        'je vais, tu vas, il/elle va, nous allez, vous allons, ils/elles vont',
        'je vais, tu vais, il/elle vait, nous allons, vous allez, ils/elles vont',
        allWrong,
      ],
      correctIndex: 0,
      explanation:
          'Le verbe « aller » au présent : je vais, tu vas, il/elle va, nous allons, vous allez, ils/elles vont ; c\'est un verbe du troisième groupe à la conjugaison irrégulière.',
      source: 'Conjugaison — Verbe « aller » au présent',
    ),
    Question(
      subject: 'الفرنسية',
      text: 'Pour enseigner le point de grammaire « le pluriel des noms en -al », l\'enseignant devra faire remarquer que',
      options: [
        'la plupart des noms en -al font leur pluriel en -aux, avec quelques exceptions (bals, carnavals)',
        'tous les noms en -al font leur pluriel en -als sans exception',
        'aucun nom en -al ne change de forme au pluriel',
        'les noms en -al prennent toujours un -x au singulier',
        allWrong,
      ],
      correctIndex: 0,
      explanation:
          'Règle : les noms en -al font leur pluriel en -aux (cheval→chevaux) ; exceptions notoires : bals, carnavals, festivals, chacals, récitals.',
      source: 'Orthographe grammaticale — Pluriel des noms en -al',
    ),
    Question(
      subject: 'الفرنسية',
      text: 'Le texte narratif que l\'élève découvre au primaire se caractérise par',
      options: [
        'une situation initiale, des péripéties et une situation finale',
        'une thèse et des arguments uniquement',
        'des consignes à suivre uniquement',
        'une succession d\'images sans texte',
        allWrong,
      ],
      correctIndex: 0,
      explanation:
          'Le schéma narratif comprend généralement : situation initiale, élément perturbateur, péripéties, élément de résolution et situation finale.',
      source: 'Typologie des textes — Schéma narratif',
    ),
    Question(
      subject: 'الفرنسية',
      text: 'En vocabulaire, le préfixe « in- » dans le mot « illisible » exprime',
      options: [
        'la négation (contraire de lisible)',
        'l\'augmentation de la taille',
        'la répétition de l\'action',
        'le lieu d\'origine',
        allWrong,
      ],
      correctIndex: 0,
      explanation:
          'Le préfixe « in- » (avec ses variantes il-, im-, ir-) marque la négation : illisible = qui ne peut pas être lu.',
      source: 'Vocabulaire — Préfixes de négation',
    ),
    Question(
      subject: 'الفرنسية',
      text: 'Pour développer la fluidité en lecture, on peut proposer à l\'élève de',
      options: [
        'relire plusieurs fois un même texte à voix haute avec un modèle',
        'lire un texte nouveau chaque minute sans relecture',
        'lire le texte le plus vite possible sans articulation',
        'éviter toute lecture à voix haute',
        allWrong,
      ],
      correctIndex: 0,
      explanation:
          'La fluidité s\'améliore par la lecture répétée (relectures d\'un même texte), la lecture avec modèle et les lectures chorales, sans négliger l\'articulation.',
      source: 'Référentiel — Fluidité en lecture',
    ),
    Question(
      subject: 'الفرنسية',
      text: 'Dans la production écrite au primaire, le brouillon sert à',
      options: [
        'formuler, organiser et améliorer progressivement les idées',
        'recopier le texte définitif directement',
        'dessiner sans lien avec le texte',
        'compter les mots sans les relire',
        allWrong,
      ],
      correctIndex: 0,
      explanation:
          'Le brouillon est un espace d\'essai et de révision : on y cherche des idées, on les organise, on réécrit et on améliore avant de recopier la version finale.',
      source: 'Guide pédagogique — Production écrite et brouillon',
    ),
    Question(
      subject: 'الفرنسية',
      text: 'L\'acte de langage « demander poliment » se réalise en classe par des formules comme',
      options: [
        '« Est-ce que tu peux me prêter ton crayon, s\'il te plaît ? »',
        '« Donne-moi ton crayon immédiatement ! »',
        '« Tu es obligé de me prêter ton crayon »',
        '« J\'ai le droit de prendre ton crayon »',
        allWrong,
      ],
      correctIndex: 0,
      explanation:
          'La politesse dans l\'acte de demande passe par des formules interrogatives et conditionnelles : « Est-ce que tu peux... », « Pourrais-tu... », accompagnées de « s\'il te plaît ».',
      source: 'Actes de langage — Demande polie',
    ),
    Question(
      subject: 'الفرنسية',
      text: 'En orthographe d\'usage, le mot « champignon » s\'écrit avec',
      options: [
        'un « p » et un « g » suivi de « n »',
        'un « p » et un « j » suivi de « n »',
        'deux « p » et un « g »',
        'un « b » et un « g »',
        allWrong,
      ],
      correctIndex: 0,
      explanation:
          '« Champignon » : c-h-a-m-p-i-g-n-o-n ; la suite « gn » transcrit le son [ɲ] et le « p » est suivi de « i ».',
      source: 'Orthographe d\'usage — Mots difficiles',
    ),
    Question(
      subject: 'الفرنسية',
      text: 'Pour évaluer l\'expression écrite au primaire, on utilise généralement une grille prenant en compte',
      options: [
        'le contenu, la structure, la syntaxe, le vocabulaire et l\'orthographe',
        'la seule longueur du texte',
        'la seule calligraphie',
        'la vitesse d\'écriture uniquement',
        allWrong,
      ],
      correctIndex: 0,
      explanation:
          'La grille d\'évaluation de l\'expression écrite repose sur des critères : adéquation au sujet, organisation, richesse du vocabulaire, correction syntaxique et orthographique.',
      source: 'Référentiel d\'évaluation — Expression écrite',
    ),
    Question(
      subject: 'الفرنسية',
      text: 'La séance de remédiation orthographique doit se fonder sur',
      options: [
        'les erreurs réellement commises par les élèves lors des productions',
        'des exercices choisis au hasard',
        'des dictées hors programme',
        'la simple répétition de la règle au tableau',
        allWrong,
      ],
      correctIndex: 0,
      explanation:
          'La remédiation s\'appuie sur l\'analyse des erreurs constatées dans les productions et dictées des élèves, pour proposer des activités ciblées de traitement.',
      source: 'Référentiel — Remédiation orthographique',
    ),
    Question(
      subject: 'الفرنسية',
      text: 'En expression orale au primaire, le récit d\'expérience vécue permet à l\'élève de',
      options: [
        'raconter un événement vécu en respectant l\'ordre des faits et en s\'exprimant clairement',
        'lire un texte écrit par l\'enseignant',
        'réciter une poésie apprise par cœur',
        'répéter des phrases sans lien avec lui',
        allWrong,
      ],
      correctIndex: 0,
      explanation:
          'Le récit d\'expérience vécue mobilise l\'élève comme locuteur : il organise son propos, respecte la chronologie et développe son aisance à l\'oral.',
      source: 'Guide pédagogique — Expression orale',
    ),
    Question(
      subject: 'الفرنسية',
      text: 'Dans l\'apprentissage de la lecture, la méconnaissance du principe alphabétique se traduit par',
      options: [
        'l\'incapacité à associer les graphèmes aux phonèmes correspondants',
        'la lecture très rapide sans erreur',
        'une écriture calligraphiée parfaite',
        'une bonne compréhension orale',
        allWrong,
      ],
      correctIndex: 0,
      explanation:
          'Le principe alphabétique est la correspondance entre les graphèmes (lettres) et les phonèmes (sons) ; sa non-maîtrise bloque le décodage.',
      source: 'Référentiel — Principe alphabétique',
    ),
    Question(
      subject: 'الفرنسية',
      text: 'La compréhension implicite en lecture désigne',
      options: [
        'la compréhension de ce qui n\'est pas dit explicitement (inférences)',
        'la compréhension littérale du texte',
        'la lecture des mots nouveaux uniquement',
        'la connaissance du vocabulaire uniquement',
        allWrong,
      ],
      correctIndex: 0,
      explanation:
          'La compréhension implicite exige de faire des inférences : combler des blancs du texte à partir d\'indices et de ses connaissances, au-delà du sens littéral.',
      source: 'Didactique de la lecture — Compréhension implicite',
    ),
    Question(
      subject: 'الفرنسية',
      text: 'Pour enseigner « le présent de l\'impératif », l\'enseignant mettra l\'accent sur',
      options: [
        'l\'expression de l\'ordre, du conseil et de la consigne avec trois personnes (tu, nous, vous)',
        'l\'expression du passé avec cinq personnes',
        'l\'expression du futur avec toutes les personnes',
        'l\'accord avec un COD placé avant',
        allWrong,
      ],
      correctIndex: 0,
      explanation:
          'L\'impératif présent ne se conjugue qu\'à trois personnes : tu, nous, vous ; il sert à donner un ordre, un conseil ou une consigne.',
      source: 'Conjugaison — Impératif présent',
    ),
    Question(
      subject: 'الفرنسية',
      text: 'La pédagogie du jeu en classe de FLE au primaire vise à',
      options: [
        'motiver et faire réinvestir la langue dans des situations ludiques et authentiques',
        'occuper les élèves sans objectif d\'apprentissage',
        'récompenser uniquement les bons élèves',
        'évaluer la concentration par le silence',
        allWrong,
      ],
      correctIndex: 0,
      explanation:
          'Le jeu pédagogique crée un contexte motivant de communication authentique où l\'élève réinvestit ses acquis langagiers en situation.',
      source: 'Guide pédagogique — Jeu et apprentissage du FLE',
    ),
    Question(
      subject: 'الفرنسية',
      text: 'Dans la démarche de l\'expression orale, la phase de « mise en situation » consiste à',
      options: [
        'installer le contexte et déclencher la prise de parole',
        'corriger toutes les erreurs en bloc',
        'donner la correction du devoir écrit',
        'évaluer par une note chiffrée',
        allWrong,
      ],
      correctIndex: 0,
      explanation:
          'La mise en situation crée un contexte motivant (image, question, situation vécue) qui déclenche l\'envie et le besoin de parler.',
      source: 'Didactique de l\'oral — Démarche de la séance',
    ),
    Question(
      subject: 'الفرنسية',
      text: 'En vocabulaire, le suffixe « -able » dans le mot « lavable » indique',
      options: [
        'la possibilité (qui peut être lavé)',
        'l\'action de laver',
        'le lieu où l\'on lave',
        'la personne qui lave',
        allWrong,
      ],
      correctIndex: 0,
      explanation:
          'Le suffixe « -able »/« -ible » forme des adjectifs exprimant la possibilité : lavable = qui peut être lavé.',
      source: 'Vocabulaire — Suffixes',
    ),
    Question(
      subject: 'الفرنسية',
      text: 'La récitation d\'un poème en classe de français permet de travailler notamment',
      options: [
        'la mémorisation, le rythme, l\'intonation et l\'expression orale',
        'la production écrite uniquement',
        'la compréhension de textes argumentatifs uniquement',
        'l\'orthographe grammaticale uniquement',
        allWrong,
      ],
      correctIndex: 0,
      explanation:
          'La récitation travaille la mémoire, la diction, le rythme, l\'intonation et la sensibilité esthétique ; elle participe de la maîtrise de l\'oral.',
      source: 'Guide pédagogique — Poésie et récitation',
    ),
    Question(
      subject: 'الفرنسية',
      text: 'Pour corriger une production écrite au cycle primaire, l\'enseignant privilégiera',
      options: [
        'un code de correction et une grille de relecture pour guider l\'élève',
        'une correction globale sans commentaire',
        'une réécriture complète du texte par l\'enseignant',
        'la seule annotation de la note finale',
        allWrong,
      ],
      correctIndex: 0,
      explanation:
          'La correction accompagnée (code d\'erreurs, grille de relecture, commentaires ciblés) rend l\'élève acteur de l\'amélioration de son texte.',
      source: 'Référentiel — Correction de la production écrite',
    ),
    Question(
      subject: 'الفرنسية',
      text: 'En conjugaison, « je finissais » est conjugué à',
      options: [
        'l\'imparfait de l\'indicatif',
        'le passé composé',
        'le futur simple',
        'le présent de l\'indicatif',
        allWrong,
      ],
      correctIndex: 0,
      explanation:
          '« Je finissais » : imparfait de l\'indicatif (terminaison -ais), marquant une action passée non achevée ou habituelle.',
      source: 'Conjugaison — Imparfait de l\'indicatif',
    ),
    Question(
      subject: 'الفرنسية',
      text: 'L\'exploitation d\'un dialogue enregistré en classe de FLE vise à développer',
      options: [
        'la compréhension orale et la production orale en interaction',
        'la seule transcription écrite du dialogue',
        'la mémorisation du dialogue sans compréhension',
        'la grammaire implicite sans activité orale',
        allWrong,
      ],
      correctIndex: 0,
      explanation:
          'Le dialogue enregistré est un support pour travailler l\'écoute (compréhension) puis l\'interaction orale (rejouer, adapter, poursuivre le dialogue).',
      source: 'Guide pédagogique — Supports audio',
    ),
    Question(
      subject: 'الفرنسية',
      text: 'Le critère de cohérence textuelle dans une production écrite renvoie à',
      options: [
        'l\'organisation logique et l\'enchaînement des idées dans le texte',
        'la calligraphie et la propreté de la copie',
        'le nombre de lignes écrites',
        'la longueur des phrases uniquement',
        allWrong,
      ],
      correctIndex: 0,
      explanation:
          'La cohérence textuelle concerne la progression logique des idées, l\'usage des connecteurs, la reprise de l\'information et l\'absence de contradiction.',
      source: 'Didactique du texte — Cohérence textuelle',
    ),
    Question(
      subject: 'الفرنسية',
      text: 'Pour introduire un nouveau texte en lecture, l\'enseignant commencera par',
      options: [
        'une phase d\'anticipation : émettre des hypothèses à partir du titre et des illustrations',
        'une dictée de mots du texte',
        'la lecture silencieuse et notée immédiatement',
        'la copie intégrale du texte',
        allWrong,
      ],
      correctIndex: 0,
      explanation:
          'La phase d\'anticipation (à partir du titre, des images, des indices) éveille l\'intérêt et prépare la compréhension en activant les connaissances de l\'élève.',
      source: 'Didactique de la lecture — Anticipation',
    ),
    Question(
      subject: 'الفرنسية',
      text: 'En phonétique corrective, la confusion entre les sons [b] et [p] se travaille par',
      options: [
        'des exercices de discrimination auditive et de prononciation contrastée',
        'des dictées uniquement',
        'la lecture de textes longs sans oral',
        'l\'analyse grammaticale de phrases',
        allWrong,
      ],
      correctIndex: 0,
      explanation:
          'La correction phonétique repose sur la discrimination auditive (entendre la différence) puis sur la prononciation contrastée et la réutilisation en contexte.',
      source: 'Didactique de la phonétique — Paires minimales',
    ),
    Question(
      subject: 'الفرنسية',
      text: 'Le questionnement en classe de français doit être conçu de manière à',
      options: [
        'favoriser la réflexion et la participation de tous les élèves',
        'cibler uniquement les élèves en difficulté',
        'obtenir une réponse unique prédéterminée',
        'faire avancer la leçon sans participation',
        allWrong,
      ],
      correctIndex: 0,
      explanation:
          'Un bon questionnement ouvre la réflexion, encourage l\'expression personnelle et assure la participation large, sans se limiter à une réponse stéréotypée.',
      source: 'Pédagogie — Techniques de questionnement',
    ),
    Question(
      subject: 'الفرنسية',
      text: 'L\'analyse des erreurs en production écrite permet à l\'enseignant de',
      options: [
        'repérer les difficultés récurrentes et planifier la remédiation',
        'classer les élèves sans suite',
        'sanctionner les élèves fautifs',
        'réduire le programme de la classe',
        allWrong,
      ],
      correctIndex: 0,
      explanation:
          'L\'erreur est une source d\'information sur les acquis et les difficultés ; son analyse guide la planification des activités de remédiation.',
      source: 'Référentiel — Traitement de l\'erreur',
    ),
    Question(
      subject: 'الفرنسية',
      text: 'Le message que l\'élève doit comprendre ou produire en classe de FLE doit être',
      options: [
        'adapté à son âge, à son niveau et à des situations de communication plausibles',
        'toujours le même quel que soit le niveau',
        'exclusivement grammatical sans contexte',
        'traduit systématiquement en arabe',
        allWrong,
      ],
      correctIndex: 0,
      explanation:
          'Les situations de communication sont choisies en fonction de l\'âge et du niveau des élèves, avec des énoncés authentiques et plausibles.',
      source: 'CECRL — Approche communicative',
    ),
    Question(
      subject: 'الفرنسية',
      text: 'En grammaire, « ils sont partis tôt » : le participe passé « partis » s\'accorde avec',
      options: [
        'le sujet « ils » (auxiliaire être)',
        'le COD placé avant le verbe',
        'le complément circonstanciel « tôt »',
        'le nom du verbe sans relation',
        allWrong,
      ],
      correctIndex: 0,
      explanation:
          'Avec l\'auxiliaire « être », le participe passé s\'accorde en genre et en nombre avec le sujet : « ils » (masculin pluriel) → « partis ».',
      source: 'Orthographe grammaticale — Accord du participe passé',
    ),
    Question(
      subject: 'الفرنسية',
      text: 'Pour favoriser l\'autonomie de l\'élève en lecture, l\'enseignant l\'amène à',
      options: [
        'utiliser des stratégies de dépannage : inférer, anticiper, survoler, repérer',
        'attendre toujours les explications du maître',
        'éviter tout texte non appris en classe',
        'mémoriser les textes sans comprendre',
        allWrong,
      ],
      correctIndex: 0,
      explanation:
          'L\'autonomie du lecteur passe par la maîtrise de stratégies : anticipation, repérage d\'indices, inférences, retour en arrière, utilisation du contexte.',
      source: 'Référentiel — Stratégies de lecture',
    ),
    Question(
      subject: 'الفرنسية',
      text: 'Le texte descriptif se reconnaît principalement à',
      options: [
        'l\'emploi de repères dans l\'espace et de notations sensorielles (vue, ouïe, odeur...)',
        'l\'ordre chronologique des événements',
        'des consignes à l\'impératif',
        'des arguments et des exemples',
        allWrong,
      ],
      correctIndex: 0,
      explanation:
          'La description organise les éléments dans l\'espace, emploie un vocabulaire précis et des perceptions sensorielles pour rendre compte d\'un lieu, d\'un objet ou d\'un personnage.',
      source: 'Typologie des textes — Description',
    ),
    Question(
      subject: 'الفرنسية',
      text: 'Dans l\'apprentissage précoce de la lecture, l\'entraînement à la conscience syllabique consiste à',
      options: [
        'segmenter les mots en syllabes et les manipuler (fusionner, supprimer, inverser)',
        'apprendre l\'alphabet sans lien avec les sons',
        'copier des phrases entières',
        'lire des textes longs directement',
        allWrong,
      ],
      correctIndex: 0,
      explanation:
          'La conscience syllabique (segmentation, fusion, suppression de syllabes) prépare la conscience phonémique et facilite l\'entrée dans la lecture.',
      source: 'Référentiel — Conscience syllabique',
    ),
    Question(
      subject: 'الفرنسية',
      text: 'La production orale en interaction se distingue de la production orale en continu par',
      options: [
        'l\'alternance des tours de parole entre deux ou plusieurs interlocuteurs',
        'la longueur du texte produit',
        'l\'absence de contexte de communication',
        'l\'emploi de l\'écrit uniquement',
        allWrong,
      ],
      correctIndex: 0,
      explanation:
          'L\'interaction orale implique un échange : prendre la parole, écouter, réagir, négocier le sens, contrairement au monologue de la production continue.',
      source: 'CECRL — Activités langagières',
    ),
    Question(
      subject: 'الفرنسية',
      text: 'Pour enseigner le vocabulaire des animaux, l\'activité la plus appropriée au primaire est',
      options: [
        'une activité de tri et de catégorisation à partir d\'images et de mots',
        'une leçon magistrale de définitions à mémoriser',
        'une dictée des noms d\'animaux sans support',
        'une analyse morphologique des noms uniquement',
        allWrong,
      ],
      correctIndex: 0,
      explanation:
          'Le vocabulaire se construit par des activités de manipulation : classer, catégoriser, apparier image-mot, créer des champs lexicaux.',
      source: 'Guide pédagogique — Vocabulaire et activités de catégorisation',
    ),
    Question(
      subject: 'الفرنسية',
      text: 'L\'erreur dans l\'apprentissage d\'une langue étrangère est considérée aujourd\'hui comme',
      options: [
        'une étape normale et une source d\'information pour l\'enseignement',
        'un échec définitif de l\'apprenant',
        'un comportement à sanctionner systématiquement',
        'une preuve d\'inaptitude à la langue',
        allWrong,
      ],
      correctIndex: 0,
      explanation:
          'L\'erreur est une trace du processus d\'acquisition ; elle renseigne sur les stratégies de l\'apprenant et oriente les activités de remédiation.',
      source: 'Didactique des langues — Statut de l\'erreur',
    ),
    Question(
      subject: 'الفرنسية',
      text: 'Le futur proche « je vais manger » est formé avec',
      options: [
        'le verbe « aller » au présent + infinitif',
        'le verbe « venir » au présent + infinitif',
        'l\'auxiliaire « avoir » + participe passé',
        'le verbe « aller » au futur + infinitif',
        allWrong,
      ],
      correctIndex: 0,
      explanation:
          'Le futur proche = aller (présent) + infinitif : « je vais manger » ; il exprime un événement proche du moment de parole.',
      source: 'Conjugaison — Futur proche',
    ),
    Question(
      subject: 'الفرنسية',
      text: 'En lecture, le déchiffrage lent et syllabique sans accès au sens révèle',
      options: [
        'une lecture non automatisée qui nécessite un entraînement à la fluidité',
        'une excellente maîtrise de la lecture',
        'un refus volontaire de lire',
        'une préférence pour la lecture silencieuse',
        allWrong,
      ],
      correctIndex: 0,
      explanation:
          'Le décodage non automatisé absorbe les ressources attentionnelles et gêne la compréhension ; il faut entraîner la fluidité par des relectures répétées.',
      source: 'Référentiel — Lecture et fluidité',
    ),
    Question(
      subject: 'الفرنسية',
      text: 'La séance de conjugaison au primaire doit débuter par',
      options: [
        'une situation de communication faisant apparaître la forme verbale à étudier',
        'la récitation du tableau de conjugaison sans contexte',
        'une interrogeration écrite de conjugaison',
        'la correction d\'une dictée précédente',
        allWrong,
      ],
      correctIndex: 0,
      explanation:
          'On part d\'une situation où la forme verbale est employée en contexte pour en dégager le sens, puis la conjugaison, puis la systématisation.',
      source: 'Guide pédagogique — Conjugaison : démarche',
    ),
    Question(
      subject: 'الفرنسية',
      text: 'Dans un texte argumentatif destiné au primaire, on trouve généralement',
      options: [
        'une thèse, des arguments et des exemples',
        'une recette de cuisine',
        'une liste de noms propres',
        'des consignes de sécurité',
        allWrong,
      ],
      correctIndex: 0,
      explanation:
          'Le texte argumentatif défend une opinion (thèse) appuyée par des arguments et des exemples ; il vise à convaincre le lecteur.',
      source: 'Typologie des textes — Argumentation',
    ),
    Question(
      subject: 'الفرنسية',
      text: 'La lecture à voix haute en classe de FLE doit être précédée de',
      options: [
        'un travail de compréhension et de préparation (lecture silencieuse, repérage des mots difficiles)',
        'une évaluation notée immédiatement',
        'une dictée de mots inconnus',
        'une copie intégrale du texte',
        allWrong,
      ],
      correctIndex: 0,
      explanation:
          'On ne lit à voix haute que ce que l\'on a compris ; la préparation (lecture silencieuse, découpage, entraînement) est indispensable avant la lecture oralisée.',
      source: 'Didactique de la lecture — Lecture à voix haute',
    ),
    Question(
      subject: 'الفرنسية',
      text: 'Pour évaluer le vocabulaire acquis, la tâche la plus révélatrice est',
      options: [
        'la réutilisation des mots en production (orale ou écrite) dans des contextes variés',
        'la récitation des listes de mots',
        'le repérage des mots dans le dictionnaire',
        'le comptage des mots connus',
        allWrong,
      ],
      correctIndex: 0,
      explanation:
          'Un mot est vraiment acquis lorsqu\'il est réutilisé spontanément en contexte ; l\'évaluation du vocabulaire se fait donc surtout en production.',
      source: 'Référentiel — Évaluation du vocabulaire',
    ),
    Question(
      subject: 'الفرنسية',
      text: 'En orthographe grammaticale, les homophones « a/à » se distinguent par',
      options: [
        '« a » est le verbe avoir (on peut dire « avait ») ; « à » est une préposition',
        '« a » est toujours une préposition',
        '« à » est le verbe avoir au présent',
        'ils sont interchangeables dans la phrase',
        allWrong,
      ],
      correctIndex: 0,
      explanation:
          'Astuce : si l\'on peut remplacer par « avait », c\'est le verbe « a » ; sinon, c\'est la préposition « à ».',
      source: 'Orthographe grammaticale — Homophones « a/à »',
    ),
    Question(
      subject: 'الفرنسية',
      text: 'La lecture documentaire au primaire suppose de faire produire à l\'élève',
      options: [
        'une fiche de lecture ou un résumé organisé des informations retenues',
        'une copie intégrale du document',
        'une récitation du texte',
        'une dictée du document',
        allWrong,
      ],
      correctIndex: 0,
      explanation:
          'Après la lecture documentaire, l\'élève reformule, organise et restitue l\'information : fiche, résumé, schéma, affiche.',
      source: 'Guide pédagogique — Lecture documentaire',
    ),
    Question(
      subject: 'الفرنسية',
      text: 'Pour gérer les erreurs orales en classe de FLE, l\'enseignant doit',
      options: [
        'les traiter avec bienveillance en privilégiant la reformulation et la reprise',
        'interrompre systématiquement l\'élève pour tout corriger',
        'ignorer complètement l\'erreur',
        'sanctionner l\'erreur par une punition',
        allWrong,
      ],
      correctIndex: 0,
      explanation:
          'La correction bienveillante (reformulation, reprise correcte, autocorrection) encourage l\'élève à s\'exprimer sans crainte de l\'erreur.',
      source: 'Didactique de l\'oral — Traitement de l\'erreur',
    ),
    Question(
      subject: 'الفرنسية',
      text: 'Le jeu de rôle en classe de FLE permet particulièrement de travailler',
      options: [
        'l\'expression orale en situation simulée de communication',
        'la seule écriture de dialogues',
        'la compréhension de textes écrits uniquement',
        'la conjugaison par cœur',
        allWrong,
      ],
      correctIndex: 0,
      explanation:
          'Le jeu de rôle place l\'élève dans une situation simulée (acheter, demander, saluer) où il mobilise la langue pour communiquer.',
      source: 'Guide pédagogique — Jeu de rôle',
    ),
    Question(
      subject: 'الفرنسية',
      text: 'En début de séance de lecture, le rappel de la séance précédente a pour fonction de',
      options: [
        'réactiver les acquis et créer une continuité dans l\'apprentissage',
        'noter les élèves en début de chaque heure',
        'passer à une activité nouvelle sans lien',
        'occuper le temps de la récréation',
        allWrong,
      ],
      correctIndex: 0,
      explanation:
          'Le rappel des acquis antérieurs (phase de réactivation) assure la continuité pédagogique et prépare l\'intégration des nouveaux apprentissages.',
      source: 'Didactique — Phases d\'une séance de lecture',
    ),
    Question(
      subject: 'الفرنسية',
      text: 'La fiche de préparation (fiche pédagogique) de la séance de français doit comporter notamment',
      options: [
        'les objectifs, le matériel, le déroulement et l\'évaluation',
        'la liste des élèves de la classe',
        'le calendrier des vacances scolaires',
        'le programme des réunions administratives',
        allWrong,
      ],
      correctIndex: 0,
      explanation:
          'La fiche de préparation structure la séance : compétences visées, objectifs, supports et matériel, déroulement détaillé des étapes et modalités d\'évaluation.',
      source: 'Guide pédagogique — Fiche de préparation',
    ),
  ];

  /// أسئلة مادة الفرنسية.
  static List<Question> get questions => List.unmodifiable(_questions);
}
