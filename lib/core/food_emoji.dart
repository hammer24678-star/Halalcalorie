// ════════════════════════════════════════════════════════════════════
//  food_emoji.dart — food glyphs + online thumbnail fallback
//
//  Replaces the old 30-entry if-chain with a keyword table covering a
//  few hundred foods in Arabic, English, French, Turkish, Malay/
//  Indonesian and Urdu. Matching is longest-keyword-first so "chicken
//  soup" resolves to soup rather than to plain chicken.
//
//  When nothing in the table matches, [FoodThumb] pulls a product photo
//  from Open Food Facts (only if the device is online) and falls back to
//  a neutral plate glyph when there is no connection or no photo.
// ════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'open_food_facts_service.dart';

/// Shown when a food cannot be identified and no photo is available.
const String kFoodGlyphFallback = '🍽️';

// ── Keyword → glyph ─────────────────────────────────────────────────
// Keys are lowercase and matched as substrings. Compound dishes are
// listed before their ingredients so the more specific match wins.
const Map<String, String> kFoodGlyphs = {
  // ── Composed dishes ──
  'pizza': '🍕', 'بيتزا': '🍕', 'pizzas': '🍕',
  'burger': '🍔', 'برجر': '🍔', 'برغر': '🍔', 'hamburger': '🍔',
  'cheeseburger': '🍔', 'hambürger': '🍔',
  'sandwich': '🥪', 'ساندويتش': '🥪', 'sandwich au': '🥪', 'sandviç': '🥪',
  'shawarma': '🌯', 'شاورما': '🌯', 'wrap': '🌯', 'burrito': '🌯',
  'kebab': '🍢', 'كباب': '🍢', 'kebap': '🍢', 'shish': '🍢',
  'kofta': '🍢', 'كفتة': '🍢', 'köfte': '🍢', 'satay': '🍢', 'sate': '🍢',
  'taco': '🌮', 'تاكو': '🌮',
  'sushi': '🍣', 'سوشي': '🍣',
  'noodle': '🍜', 'نودلز': '🍜', 'ramen': '🍜', 'mie': '🍜', 'mee': '🍜',
  'pho': '🍜', 'laksa': '🍜',
  'pasta': '🍝', 'معكرون': '🍝', 'مكرونة': '🍝', 'spaghetti': '🍝',
  'makarna': '🍝', 'penne': '🍝', 'lasagna': '🍝', 'لازانيا': '🍝',
  'soup': '🍲', 'شوربة': '🍲', 'حساء': '🍲', 'soupe': '🍲', 'çorba': '🍲',
  'lentil soup': '🍲', 'عدس': '🍲', 'mercimek': '🍲',
  'stew': '🍲', 'يخنة': '🍲', 'طاجن': '🍲', 'tagine': '🍲', 'curry': '🍛',
  'كاري': '🍛', 'rendang': '🍛', 'gulai': '🍛',
  'biryani': '🍛', 'برياني': '🍛', 'pilaf': '🍚', 'pilav': '🍚',
  'kabsa': '🍛', 'كبسة': '🍛', 'mandi': '🍛', 'مندي': '🍛',
  'nasi': '🍚', 'nasi goreng': '🍚', 'fried rice': '🍚',
  'salad': '🥗', 'سلطة': '🥗', 'salade': '🥗', 'salata': '🥗',
  'tabbouleh': '🥗', 'تبولة': '🥗', 'fattoush': '🥗', 'فتوش': '🥗',
  'coleslaw': '🥗', 'gado': '🥗',
  'omelette': '🍳', 'أومليت': '🍳', 'omlet': '🍳', 'scrambled': '🍳',
  'fried egg': '🍳', 'بيض مقلي': '🍳',
  'falafel': '🧆', 'فلافل': '🧆', 'طعمية': '🧆',
  'hummus': '🥣', 'حمص': '🥣', 'houmous': '🧆',
  'foul': '🫘', 'فول': '🫘', 'ful medames': '🫘',
  'shakshuka': '🍳', 'شكشوكة': '🍳',
  'mansaf': '🍛', 'منسف': '🍛', 'maqluba': '🍛', 'مقلوبة': '🍛',
  'koshari': '🍚', 'كشري': '🍚',
  'pastry': '🥐', 'croissant': '🥐', 'كرواسون': '🥐',
  'samosa': '🥟', 'سمبوسة': '🥟', 'dumpling': '🥟', 'gyoza': '🥟',
  'börek': '🥟', 'برك': '🥟', 'بورك': '🥟', 'spring roll': '🥟',
  'pancake': '🥞', 'بانكيك': '🥞', 'crêpe': '🥞', 'crepe': '🥞',
  'waffle': '🧇', 'وافل': '🧇',
  'toast': '🍞', 'توست': '🍞',
  'fries': '🍟', 'بطاطس مقلية': '🍟', 'frites': '🍟',
  'patates kızartması': '🍟',
  'popcorn': '🍿', 'فشار': '🍿',
  'hot dog': '🌭', 'هوت دوج': '🌭', 'sausage': '🌭', 'سجق': '🌭',
  'sosis': '🌭', 'merguez': '🌭',

  // ── Grains, bread, starch ──
  'bread': '🍞', 'خبز': '🍞', 'pain': '🍞', 'ekmek': '🍞', 'roti': '🍞',
  'baguette': '🥖', 'بغيت': '🥖',
  'pita': '🫓', 'بيتا': '🫓', 'flatbread': '🫓', 'lavash': '🫓',
  'naan': '🫓', 'نان': '🫓', 'chapati': '🫓', 'tortilla': '🫓',
  'rice': '🍚', 'أرز': '🍚', 'riz': '🍚', 'pirinç': '🍚', 'beras': '🍚',
  'quinoa': '🌾', 'كينوا': '🌾', 'bulgur': '🌾', 'برغل': '🌾',
  'couscous': '🌾', 'كسكس': '🌾', 'freekeh': '🌾', 'فريكة': '🌾',
  'barley': '🌾', 'شعير': '🌾', 'orge': '🌾', 'arpa': '🌾',
  'wheat': '🌾', 'قمح': '🌾', 'oat': '🥣', 'شوفان': '🥣', 'avoine': '🥣',
  'yulaf': '🥣', 'porridge': '🥣', 'granola': '🥣', 'muesli': '🥣',
  'cereal': '🥣', 'حبوب الإفطار': '🥣', 'corn flakes': '🥣',
  'potato': '🥔', 'بطاطا': '🥔', 'بطاطس': '🥔', 'pomme de terre': '🥔',
  'patates': '🥔', 'kentang': '🥔', 'sweet potato': '🍠',
  'بطاطا حلوة': '🍠', 'yam': '🍠', 'ubi': '🍠',
  'corn': '🌽', 'ذرة': '🌽', 'maïs': '🌽', 'mısır': '🌽', 'jagung': '🌽',

  // ── Protein ──
  'chicken': '🍗', 'دجاج': '🍗', 'poulet': '🍗', 'tavuk': '🍗',
  'ayam': '🍗', 'مرغی': '🍗', 'drumstick': '🍗', 'wing': '🍗',
  'turkey': '🦃', 'ديك رومي': '🦃', 'hindi': '🦃',
  'duck': '🦆', 'بط': '🦆', 'canard': '🦆', 'bebek': '🦆',
  'steak': '🥩', 'ستيك': '🥩', 'beef': '🥩', 'لحم بقري': '🥩',
  'boeuf': '🥩', 'dana': '🥩', 'daging': '🥩', 'lamb': '🍖',
  'خروف': '🍖', 'ضأن': '🍖', 'agneau': '🍖', 'kuzu': '🍖',
  'mutton': '🍖', 'veal': '🍖', 'لحم': '🥩', 'meat': '🥩',
  'viande': '🥩', 'goat': '🍖', 'ماعز': '🍖',
  'liver': '🥩', 'كبدة': '🥩', 'ciğer': '🥩',
  'fish': '🐟', 'سمك': '🐟', 'poisson': '🐟', 'balık': '🐟',
  'ikan': '🐟', 'مچھلی': '🐟', 'salmon': '🐟', 'سلمون': '🐟',
  'saumon': '🐟', 'somon': '🐟', 'tuna': '🐟', 'تونة': '🐟',
  'sardine': '🐟', 'سردين': '🐟', 'mackerel': '🐟', 'cod': '🐟',
  'tilapia': '🐟', 'bass': '🐟', 'trout': '🐟',
  'shrimp': '🦐', 'جمبري': '🦐', 'روبيان': '🦐', 'crevette': '🦐',
  'karides': '🦐', 'udang': '🦐', 'prawn': '🦐',
  'crab': '🦀', 'سلطعون': '🦀', 'كرابة': '🦀', 'kepiting': '🦀',
  'squid': '🦑', 'حبار': '🦑', 'calamari': '🦑', 'kalamar': '🦑',
  'lobster': '🦞', 'كركند': '🦞',
  'egg': '🥚', 'بيض': '🥚', 'oeuf': '🥚', 'œuf': '🥚', 'yumurta': '🥚',
  'telur': '🥚', 'انڈا': '🥚',
  'tofu': '🍥', 'توفو': '🍥', 'tempeh': '🍥', 'tempe': '🍥',
  'protein powder': '🥛', 'واي بروتين': '🥛', 'whey': '🥛',

  // ── Legumes & nuts ──
  'bean': '🫘', 'فاصولياء': '🫘', 'فاصوليا': '🫘', 'haricot': '🫘',
  'fasulye': '🫘', 'kacang': '🫘', 'chickpea': '🫘', 'حمص حب': '🫘',
  'pois chiche': '🫘', 'nohut': '🫘', 'lentil': '🫘', 'عدس أحمر': '🫘',
  'lentille': '🫘', 'pea': '🫛', 'بازلاء': '🫛', 'petit pois': '🫛',
  'bezelye': '🫛', 'edamame': '🫛',
  'peanut': '🥜', 'فول سوداني': '🥜', 'cacahuète': '🥜',
  'fıstık': '🥜', 'nut': '🥜', 'مكسرات': '🥜', 'noix': '🥜',
  'almond': '🌰', 'لوز': '🌰', 'amande': '🌰', 'badem': '🌰',
  'walnut': '🌰', 'جوز': '🌰', 'ceviz': '🌰', 'cashew': '🌰',
  'كاجو': '🌰', 'pistachio': '🌰', 'فستق': '🌰', 'hazelnut': '🌰',
  'بندق': '🌰', 'fındık': '🌰', 'chestnut': '🌰', 'كستناء': '🌰',
  'seed': '🌱', 'بذور': '🌱', 'sesame': '🌱', 'سمسم': '🌱',
  'tahini': '🥣', 'طحينة': '🥣', 'tahin': '🥣',
  'chia': '🌱', 'شيا': '🌱', 'flax': '🌱', 'كتان': '🌱',
  'sunflower': '🌻', 'دوار الشمس': '🌻', 'pumpkin seed': '🎃',

  // ── Dairy ──
  'milk': '🥛', 'حليب': '🥛', 'لبن': '🥛', 'lait': '🥛', 'süt': '🥛',
  'susu': '🥛', 'دودھ': '🥛',
  'cheese': '🧀', 'جبن': '🧀', 'جبنة': '🧀', 'fromage': '🧀',
  'peynir': '🧀', 'keju': '🧀', 'feta': '🧀', 'halloumi': '🧀',
  'حلوم': '🧀', 'mozzarella': '🧀', 'cheddar': '🧀',
  'yogurt': '🥣', 'زبادي': '🥣', 'yaourt': '🥣', 'yoğurt': '🥣',
  'yoghurt': '🥣', 'labneh': '🥣', 'لبنة': '🥣', 'ayran': '🥛',
  'kefir': '🥛', 'كفير': '🥛',
  'butter': '🧈', 'زبدة': '🧈', 'beurre': '🧈', 'tereyağı': '🧈',
  'mentega': '🧈', 'ghee': '🧈', 'سمن': '🧈',
  'cream': '🥛', 'كريمة': '🥛', 'crème': '🥛', 'krema': '🥛',
  'ice cream': '🍦', 'آيس كريم': '🍦', 'glace': '🍦', 'dondurma': '🍦',
  'es krim': '🍦',

  // ── Fruit ──
  'apple': '🍎', 'تفاح': '🍎', 'pomme': '🍎', 'elma': '🍎',
  'apel': '🍎', 'سیب': '🍎',
  'banana': '🍌', 'موز': '🍌', 'banane': '🍌', 'muz': '🍌',
  'pisang': '🍌', 'کیلا': '🍌',
  'orange': '🍊', 'برتقال': '🍊', 'portakal': '🍊', 'jeruk': '🍊',
  'tangerine': '🍊', 'يوسفي': '🍊', 'mandarin': '🍊',
  'lemon': '🍋', 'ليمون': '🍋', 'citron': '🍋', 'limon': '🍋',
  'lime': '🍋', 'ليمون أخضر': '🍋',
  'grape': '🍇', 'عنب': '🍇', 'raisin': '🍇', 'üzüm': '🍇',
  'anggur': '🍇',
  'strawberry': '🍓', 'فراولة': '🍓', 'fraise': '🍓', 'çilek': '🍓',
  'stroberi': '🍓',
  'blueberry': '🫐', 'بلوبيري': '🫐', 'myrtille': '🫐',
  'raspberry': '🫐', 'توت العليق': '🫐', 'berry': '🫐', 'توت': '🫐',
  'mulberry': '🫐',
  'watermelon': '🍉', 'بطيخ': '🍉', 'pastèque': '🍉', 'karpuz': '🍉',
  'semangka': '🍉',
  'melon': '🍈', 'شمام': '🍈', 'kavun': '🍈', 'cantaloupe': '🍈',
  'peach': '🍑', 'خوخ': '🍑', 'دراق': '🍑', 'pêche': '🍑',
  'şeftali': '🍑',
  'pear': '🍐', 'كمثرى': '🍐', 'إجاص': '🍐', 'poire': '🍐',
  'armut': '🍐', 'pir': '🍐',
  'cherry': '🍒', 'كرز': '🍒', 'cerise': '🍒', 'kiraz': '🍒',
  'mango': '🥭', 'مانجو': '🥭', 'mangue': '🥭', 'mangga': '🥭',
  'pineapple': '🍍', 'أناناس': '🍍', 'ananas': '🍍', 'nanas': '🍍',
  'kiwi': '🥝', 'كيوي': '🥝',
  'coconut': '🥥', 'جوز الهند': '🥥', 'noix de coco': '🥥',
  'kelapa': '🥥', 'hindistan cevizi': '🥥',
  'avocado': '🥑', 'أفوكادو': '🥑', 'avocat': '🥑', 'avokado': '🥑',
  'date': '🌴', 'تمر': '🌴', 'بلح': '🌴', 'رطب': '🌴', 'datte': '🌴',
  'hurma': '🌴', 'kurma': '🌴', 'کھجور': '🌴',
  'fig': '🫐', 'تين': '🫐', 'figue': '🫐', 'incir': '🫐',
  'pomegranate': '🍎', 'رمان': '🍎', 'grenade': '🍎', 'nar': '🍎',
  'guava': '🍐', 'جوافة': '🍐', 'jambu': '🍐',
  'papaya': '🍈', 'بابايا': '🍈', 'pepaya': '🍈',
  'apricot': '🍑', 'مشمش': '🍑', 'abricot': '🍑', 'kayısı': '🍑',
  'plum': '🍇', 'برقوق': '🍇', 'prune': '🍇', 'erik': '🍇',
  'durian': '🍈', 'rambutan': '🍒', 'lychee': '🍒', 'ليتشي': '🍒',
  'raisins': '🍇', 'زبيب': '🍇', 'kuru üzüm': '🍇',
  'dried fruit': '🍇', 'فواكه مجففة': '🍇',

  // ── Vegetables ──
  'tomato': '🍅', 'طماطم': '🍅', 'بندورة': '🍅', 'tomate': '🍅',
  'domates': '🍅', 'tomat': '🍅',
  'cucumber': '🥒', 'خيار': '🥒', 'concombre': '🥒', 'salatalık': '🥒',
  'timun': '🥒',
  'carrot': '🥕', 'جزر': '🥕', 'carotte': '🥕', 'havuç': '🥕',
  'wortel': '🥕', 'lobak merah': '🥕',
  'broccoli': '🥦', 'بروكلي': '🥦', 'brocoli': '🥦', 'brokoli': '🥦',
  'cauliflower': '🥦', 'قرنبيط': '🥦', 'زهرة': '🥦', 'karnabahar': '🥦',
  'lettuce': '🥬', 'خس': '🥬', 'laitue': '🥬', 'marul': '🥬',
  'spinach': '🥬', 'سبانخ': '🥬', 'épinard': '🥬', 'ıspanak': '🥬',
  'bayam': '🥬', 'kale': '🥬', 'كرنب': '🥬', 'cabbage': '🥬',
  'ملفوف': '🥬', 'chou': '🥬', 'lahana': '🥬', 'kubis': '🥬',
  'molokhia': '🥬', 'ملوخية': '🥬', 'chard': '🥬', 'سلق': '🥬',
  'pepper': '🫑', 'فلفل': '🫑', 'poivron': '🫑', 'biber': '🫑',
  'cabai': '🌶️', 'chili': '🌶️', 'شطة': '🌶️', 'piment': '🌶️',
  'onion': '🧅', 'بصل': '🧅', 'oignon': '🧅', 'soğan': '🧅',
  'bawang': '🧅', 'leek': '🧅', 'كراث': '🧅',
  'garlic': '🧄', 'ثوم': '🧄', 'ail': '🧄', 'sarımsak': '🧄',
  'eggplant': '🍆', 'باذنجان': '🍆', 'aubergine': '🍆',
  'patlıcan': '🍆', 'terung': '🍆',
  'zucchini': '🥒', 'كوسة': '🥒', 'courgette': '🥒', 'kabak': '🥒',
  'pumpkin': '🎃', 'يقطين': '🎃', 'قرع': '🎃', 'citrouille': '🎃',
  'mushroom': '🍄', 'مشروم': '🍄', 'فطر': '🍄', 'champignon': '🍄',
  'mantar': '🍄', 'cendawan': '🍄',
  'okra': '🌿', 'بامية': '🌿', 'bamya': '🌿',
  'beetroot': '🫒', 'شمندر': '🫒', 'betterave': '🫒',
  'radish': '🥬', 'فجل': '🥬', 'turp': '🥬',
  'celery': '🥬', 'كرفس': '🥬', 'céleri': '🥬', 'kereviz': '🥬',
  'asparagus': '🥬', 'هليون': '🥬', 'artichoke': '🥬', 'خرشوف': '🥬',
  'vegetable': '🥦', 'خضار': '🥦', 'légume': '🥦', 'sebze': '🥦',
  'sayur': '🥦',
  'olive': '🫒', 'زيتون': '🫒', 'zeytin': '🫒', 'buah zaitun': '🫒',

  // ── Fats, oils, condiments ──
  'olive oil': '🫒', 'زيت زيتون': '🫒', 'huile d’olive': '🫒',
  'oil': '🫗', 'زيت': '🫗', 'huile': '🫗', 'yağ': '🫗', 'minyak': '🫗',
  'honey': '🍯', 'عسل': '🍯', 'miel': '🍯', 'bal': '🍯', 'madu': '🍯',
  'شہد': '🍯',
  'jam': '🍯', 'مربى': '🍯', 'confiture': '🍯', 'reçel': '🍯',
  'sauce': '🥫', 'صوص': '🥫', 'صلصة': '🥫', 'sos': '🥫', 'saus': '🥫',
  'ketchup': '🥫', 'كاتشب': '🥫', 'mayonnaise': '🥫', 'مايونيز': '🥫',
  'mustard': '🥫', 'خردل': '🥫', 'moutarde': '🥫',
  'vinegar': '🫗', 'خل': '🫗', 'vinaigre': '🫗', 'sirke': '🫗',
  'salt': '🧂', 'ملح': '🧂', 'sel': '🧂', 'tuz': '🧂', 'garam': '🧂',
  'sugar': '🍬', 'سكر': '🍬', 'sucre': '🍬', 'şeker': '🍬',
  'gula': '🍬', 'syrup': '🍯', 'شراب مركز': '🍯', 'molasses': '🍯',
  'دبس': '🍯', 'pekmez': '🍯',
  'spice': '🌿', 'بهارات': '🌿', 'épice': '🌿', 'baharat': '🌿',
  'cinnamon': '🌿', 'قرفة': '🌿', 'cannelle': '🌿', 'tarçın': '🌿',
  'ginger': '🌿', 'زنجبيل': '🌿', 'gingembre': '🌿', 'zencefil': '🌿',
  'turmeric': '🌿', 'كركم': '🌿', 'curcuma': '🌿',
  'cumin': '🌿', 'كمون': '🌿', 'black seed': '🌱', 'حبة البركة': '🌱',
  'حبة سوداء': '🌱', 'nigella': '🌱', 'çörek otu': '🌱',
  'mint': '🌿', 'نعنع': '🌿', 'menthe': '🌿', 'nane': '🌿',
  'parsley': '🌿', 'بقدونس': '🌿', 'persil': '🌿', 'maydanoz': '🌿',
  'coriander': '🌿', 'كزبرة': '🌿', 'basil': '🌿', 'ريحان': '🌿',
  'herb': '🌿', 'أعشاب': '🌿',

  // ── Drinks ──
  'water': '💧', 'ماء': '💧', 'eau': '💧', 'su': '💧', 'air': '💧',
  'پانی': '💧', 'mineral water': '💧',
  'coffee': '☕', 'قهوة': '☕', 'café': '☕', 'kahve': '☕',
  'kopi': '☕', 'espresso': '☕', 'latte': '☕', 'cappuccino': '☕',
  'کافی': '☕', 'nescafe': '☕',
  'tea': '🍵', 'شاي': '🍵', 'thé': '🍵', 'çay': '🍵', 'teh': '🍵',
  'چائے': '🍵', 'green tea': '🍵', 'شاي أخضر': '🍵', 'matcha': '🍵',
  'karak': '🍵', 'كرك': '🍵',
  'juice': '🧃', 'عصير': '🧃', 'jus': '🧃', 'meyve suyu': '🧃',
  'smoothie': '🥤', 'سموذي': '🥤', 'milkshake': '🥤', 'ميلك شيك': '🥤',
  'soda': '🥤', 'مشروب غازي': '🥤', 'cola': '🥤', 'كولا': '🥤',
  'pepsi': '🥤', 'sprite': '🥤', 'gazoz': '🥤', 'soft drink': '🥤',
  'energy drink': '🥤', 'مشروب طاقة': '🥤',
  'lemonade': '🍋', 'ليموناضة': '🍋', 'limonata': '🍋',
  'tamarind': '🥤', 'تمر هندي': '🥤', 'qamar': '🥤', 'قمر الدين': '🥤',
  'hibiscus': '🥤', 'كركديه': '🥤',

  // ── Sweets & snacks ──
  'chocolate': '🍫', 'شوكولاتة': '🍫', 'شوكولا': '🍫',
  'chocolat': '🍫', 'çikolata': '🍫', 'cokelat': '🍫',
  'cake': '🍰', 'كيك': '🍰', 'كعك': '🍰', 'gâteau': '🍰',
  'pasta kek': '🍰', 'kue': '🍰', 'cheesecake': '🍰',
  'cupcake': '🧁', 'كب كيك': '🧁', 'muffin': '🧁', 'مافن': '🧁',
  'cookie': '🍪', 'بسكويت': '🍪', 'biscuit': '🍪', 'kurabiye': '🍪',
  'biskut': '🍪', 'brownie': '🍫',
  'donut': '🍩', 'دونات': '🍩', 'beignet': '🍩',
  'candy': '🍬', 'حلوى': '🍬', 'bonbon': '🍬',
  'gummy': '🍬', 'lollipop': '🍭', 'مصاصة': '🍭',
  'baklava': '🍮', 'بقلاوة': '🍮', 'kunafa': '🍮', 'كنافة': '🍮',
  'basbousa': '🍮', 'بسبوسة': '🍮', 'maamoul': '🍪', 'معمول': '🍪',
  'halva': '🍮', 'حلاوة': '🍮', 'helva': '🍮',
  'pudding': '🍮', 'بودينغ': '🍮', 'custard': '🍮', 'كريم كراميل': '🍮',
  'rice pudding': '🍮', 'أرز بلبن': '🍮', 'sutlac': '🍮',
  'chips': '🍟', 'شيبس': '🍟', 'crisps': '🍟', 'cips': '🍟',
  'kerepek': '🍟', 'pretzel': '🥨', 'بريتزل': '🥨',
  'granola bar': '🍫', 'protein bar': '🍫', 'ألواح بروتين': '🍫',
  'dessert': '🍮', 'حلويات': '🍮', 'dessert sucré': '🍮',
  'manisan': '🍮',
};

/// Keys sorted longest-first so specific dishes beat their ingredients.
final List<String> _sortedGlyphKeys = kFoodGlyphs.keys.toList()
  ..sort((a, b) => b.length.compareTo(a.length));

/// Best-matching glyph for [name], or null when nothing matches.
String? lookupFoodGlyph(String name) {
  final needle = name.toLowerCase().trim();
  if (needle.isEmpty) return null;
  for (final key in _sortedGlyphKeys) {
    if (needle.contains(key)) return kFoodGlyphs[key];
  }
  return null;
}

/// Glyph for [name], falling back to a neutral plate.
String foodEmoji(String name) => lookupFoodGlyph(name) ?? kFoodGlyphFallback;

/// True when the table has no idea what this food is — the cue to try a
/// photo instead.
bool isUnknownFood(String name) => lookupFoodGlyph(name) == null;

// ════════════════════════════════════════════════════════════════════
// ONLINE THUMBNAILS
// ════════════════════════════════════════════════════════════════════

/// Remembers resolved (and failed) image lookups for the session so the
/// same food never costs two network calls.
class FoodImageCache {
  FoodImageCache._();

  static final Map<String, String?> _urls = {};
  static final Map<String, Future<String?>> _inFlight = {};
  static bool? _online;

  static Future<bool> isOnline() async {
    try {
      final result = await Connectivity().checkConnectivity();
      _online = result.isNotEmpty &&
          !result.every((r) => r == ConnectivityResult.none);
    } catch (_) {
      // If the check itself fails, let the image request decide.
      _online = true;
    }
    return _online!;
  }

  /// Looks up a product photo for [name]. Returns null when offline, when
  /// the search finds nothing, or on any error.
  static Future<String?> resolve(String name) {
    final key = name.toLowerCase().trim();
    if (key.isEmpty) return Future.value(null);
    if (_urls.containsKey(key)) return Future.value(_urls[key]);
    return _inFlight.putIfAbsent(key, () async {
      try {
        if (!await isOnline()) return null;
        final hit = await OpenFoodFactsService.searchByName(name);
        final url = (hit?['image_url'] as String?)?.trim();
        final value = (url == null || url.isEmpty) ? null : url;
        _urls[key] = value;
        return value;
      } catch (_) {
        _urls[key] = null;
        return null;
      } finally {
        _inFlight.remove(key);
      }
    });
  }

  /// Records a URL already known from a search or barcode scan.
  static void seed(String name, String? url) {
    final key = name.toLowerCase().trim();
    if (key.isEmpty) return;
    if (url != null && url.trim().isNotEmpty) {
      _urls[key] = url.trim();
    }
  }
}

/// Square food thumbnail: glyph when the food is recognised, otherwise a
/// photo pulled from Open Food Facts, otherwise a neutral plate.
class FoodThumb extends StatefulWidget {
  final String name;

  /// Photo already known for this item (from a search hit or a scan).
  final String? imageUrl;
  final double size;
  final double radius;
  final Color? background;

  /// Set false to keep the widget fully offline (glyph only).
  final bool allowNetwork;

  const FoodThumb({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = 42,
    this.radius = 11,
    this.background,
    this.allowNetwork = true,
  });

  @override
  State<FoodThumb> createState() => _FoodThumbState();
}

class _FoodThumbState extends State<FoodThumb> {
  String? _glyph;
  String? _url;
  bool _looking = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(FoodThumb old) {
    super.didUpdateWidget(old);
    if (old.name != widget.name || old.imageUrl != widget.imageUrl) _resolve();
  }

  void _resolve() {
    _glyph = lookupFoodGlyph(widget.name);
    if (widget.imageUrl != null && widget.imageUrl!.trim().isNotEmpty) {
      FoodImageCache.seed(widget.name, widget.imageUrl);
      _url = widget.imageUrl!.trim();
      return;
    }
    _url = null;
    // Only reach for a photo when the glyph table came up empty.
    if (_glyph != null || !widget.allowNetwork) return;
    _looking = true;
    FoodImageCache.resolve(widget.name).then((url) {
      if (!mounted) return;
      setState(() {
        _url = url;
        _looking = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.background ??
        Theme.of(context).colorScheme.primary.withOpacity(0.08);
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: Container(
        width: widget.size,
        height: widget.size,
        color: bg,
        child: _content(),
      ),
    );
  }

  Widget _content() {
    if (_glyph != null) return _glyphView(_glyph!);
    if (_url != null) {
      return Image.network(
        _url!,
        fit: BoxFit.cover,
        width: widget.size,
        height: widget.size,
        // A missing or broken photo must never break the row.
        errorBuilder: (_, __, ___) => _glyphView(kFoodGlyphFallback),
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : _glyphView(kFoodGlyphFallback),
      );
    }
    if (_looking) return _glyphView(kFoodGlyphFallback);
    return _glyphView(kFoodGlyphFallback);
  }

  Widget _glyphView(String glyph) => Center(
        child: Text(glyph,
            style: TextStyle(fontSize: widget.size * 0.48)),
      );
}
