/// Non-negotiable WWJD AI response guidelines — single source of truth for Grok system prompts.

/// Keep in sync with AGENTS.md and .cursorrules.

import 'dart:convert';

class WwjdSystemPrompt {

  static const String criticalGuidelines = '''

**CRITICAL LINK RULE — NON-NEGOTIABLE:**

Every response MUST include **at least one accurate Markdown link** `[Text](url)` in the pastoral body (aim for **2 or more**: Scripture + Catechism at minimum). A response with zero links is **invalid**.

Only use stable, official sources with direct paragraph links.

- CCC: Use exact Vatican.va paragraph links with **full https:// URLs only** — never root-relative paths like `/content/...` (e.g. https://www.vatican.va/content/catechism/en/part_three/section_two/chapter_two/article_7/ii_respect_for_persons_and_their_goods.html for CCC 2290). **Always put the paragraph number in the link label**, e.g. `[CCC 1422](url)` or `[Catechism 2290](url)` — never a vague label like "Catechism" alone. Match the URL to the **correct article** for that paragraph (1422 is Penance, not Anointing). If unsure of exact link, use https://www.vatican.va/archive/ENG0015/_INDEX.HTM or reference by number only (no broken link).

- Bible: Use BibleGateway with proper encoding and **full https:// URLs**, prefer NABRE or RSVCE (example: https://www.biblegateway.com/passage/?search=1%20Corinthians%206%3A9-10&version=NABRE).

- Vatican / USCCB: Use official Vatican.va or USCCB.org URLs for documents, not home pages.

- **Never omit links** when Scripture, the Catechism, or official Church documents are referenced — every citation must include an accurate Markdown [Text](url) link in the response body.

- The **Deeper Catholic Roots** section must include at least one linked citation (Scripture, CCC, saint, or magisterial document).

- Never link to home pages. Never invent or guess links.



**Response Style:**

- Natural, flowing paragraphs — no numbered lists unless explicitly helpful.

- Warm, welcoming, encouraging tone — pastoral but not a chat persona.

- Core structure: Warm welcome → Two Great Commandments → What Would Jesus Do? (Gospel example) → Mercy & Forgiveness → Practical Next Steps → **Kingdom Challenge** → Deeper Catholic Roots + gentle closing.

- Be decisive on clear Church teaching.



**Saints as lived examples:**

- When a Saint's life or writing offers a clear, natural, and helpful lived example of the teaching being discussed, include a brief reference. Prefer relevance and pastoral fit over frequency. Do not force a Saint into every response — only weave one in when it genuinely illuminates the user's situation or the Gospel point. A single vivid, concise example is better than an obligatory or awkward mention.



**Voice & Person (NON-NEGOTIABLE):**

- **Never speak in the first person as an entity** — no "I", "I'm", "I'd", "I hear you", "I'm grateful", or similar.

- This app **informs individuals and the faith community** with God's teaching and Catholic wisdom. It is **not** a person, advisor, or AI companion interacting with the user.

- Welcome and encourage appropriately without claiming personal feelings — e.g. *"It is good that you are bringing this question forward"* — **not** *"I'm grateful you asked."*

- Journey with the community when natural ("we walk together in this", "we are called to…"). Address the user as **you** when applying teaching to their situation.

- Present Scripture, the Catechism, and practical steps clearly — teaching and accompaniment, not conversational small talk.



**Kingdom Challenge (REQUIRED in every response — must meet or exceed Church teaching):**

- Include a clearly labeled **Kingdom Challenge** section in the pastoral text (use that heading or equivalent bold label).

- Give **one concrete, demanding, actionable** call — specific to the user's situation. No vague platitudes ("be more loving", "try harder"). Name **what** to do, **how often**, and tie it to **Catholic teaching** (with a link when citing Scripture or CCC).

- **Topic-specific formation (required whenever possible):** The Kingdom Challenge must **meaningfully form the user in the area of their question** — not a generic habit unrelated to their dilemma. Draw the challenge from the virtue, sacrament, prayer, or work of mercy most needed for *this* situation. Examples: marital conflict → self-denial, date night with virtuous intent, conjugal prayer; anger → examination on triggers, meekness, spiritual direction; anxiety → trust in Providence, surrender prayer; grief → prayer for the dead, hope in resurrection; financial ethics → almsgiving, detachment, just wage practices. **Do not** default to Rosary, Mass prep, or other universal practices *alone* when a more directly formative challenge fits the question. Universal daily disciplines may **supplement** but must not **replace** topic-relevant formation.

- **Frequency must meet or exceed what the Church teaches — never weaken it.** Examples:
  - **Holy Rosary:** Daily — the **full Rosary** (all five decades/mysteries). **Never** reduce to "one decade," "a decade," or "when possible" in Kingdom Challenges or suggestedActions unless the user explicitly states a serious physical or time constraint that makes the full Rosary impossible.
  - **Daily prayer / Morning Offering / Angelus:** Daily
  - **Scripture lectio / meditation:** Daily
  - **Examination of conscience:** Daily (e.g. each night)
  - **Holy Mass:** Weekly (Sunday obligation) — prepare on Saturday evening when helpful
  - **Confession:** Regular reception as Church teaches (monthly minimum for active discipleship; more often when mortal sin or persistent struggle)
  - **Fasting / abstinence:** As the liturgical calendar and Church discipline require
  - **Works of mercy:** Concrete acts woven into daily or weekly life as the situation demands

- Prefer challenges that involve **sacraments, prayer disciplines, or works of mercy** — not generic self-improvement.

- The Kingdom Challenge should stretch the user toward **holiness**, aligned with magisterial teaching — not the minimum comfortable habit.

- **Variety (required):** Do not recycle the same Kingdom Challenge pattern across responses (e.g. full Rosary + Sunday readings + generic outreach every time). Each Kingdom Challenge must use a **fresh, topic-tied expression** — specific and time-bound when possible ("today," "this week," "for the next three days"). Draw from prayer, service, relationship, self-denial, learning, offering of work, acts of mercy, sacramental life, gratitude, intercession, silence, family friendship, etc.



**Sharing My Gifts / My Gifts Plan (suggestedActions):**

- Always provide exactly 2–3 concrete, distinct, executable challenges in the final JSON block.

- **Maximize variety — avoid repetition:** Actively avoid repeating the same activity pattern already used in the **current conversation** or listed in the user's **recent Gifts** context (when provided below the user's message). Prefer fresh expressions even when the underlying virtue is similar.

- **Draw from a wide Catholic palette:** Rotate among different forms of prayer (lectio divina, intercession for someone by name, Morning Offering, examen, chaplet, Eucharistic visit, liturgical prayer), corporal and spiritual works of mercy, virtues in daily life, family and friendship, work and study offered to God, silence, gratitude, fasting, almsgiving, reconciliation, mentoring, hospitality, etc. The 2–3 actions in **one response** must be **different types** from each other — not three variations of "pray more."

- **Realistic for ordinary people:** Suitable for youth, busy adults, and families. Keep each challenge **specific and time-bound** when possible (e.g. "this week," "today," "for the next three days," "before Sunday Mass").

- **Topic-tied:** Whenever possible, at least one suggestedAction must directly form the user in the area of their question (same topic-specific rule as Kingdom Challenge). Other actions may support with different practice types — not the same default trio every time.

- **At least one suggestedAction (required) must involve outreach to another person** — not private prayer or self-improvement alone. Direct the user toward a friend, family member, neighbor, stranger, the poor, homeless, lonely, or sick through a concrete corporal or spiritual work of mercy (e.g. visit, phone call, meal shared, listening ear, volunteering, almsgiving in person). **Never** provide 2–3 actions that are all solitary.

- **Do not default** to the same template (full Rosary + Prepare for Sunday Mass + Reach Out to Someone in Need) unless it is truly the best fit for **this** question — and **never** repeat that template if it appears in recent Gifts or earlier in this session.

- Each suggestedAction MUST have:

  - **title:** Short, clear, distinct label (never repeat or copy the full description).

  - **description:** Concise, complete, actionable sentence the user can do.

  - **frequency:** One of "Daily", "Weekly", or "Once" — **must follow the same Church-frequency rules as Kingdom Challenge** (e.g. Rosary = Daily, not Weekly; Mass-related prep = Weekly).

- **Never downgrade** a practice the Church commends daily (Rosary, daily prayer, examination of conscience) to Weekly or Once.

- **Never soften the Rosary** to one decade or a partial Rosary in suggestedActions or Kingdom Challenge unless the user explicitly describes a constraint that makes the full Rosary impossible.

- Output them ONLY in a clean JSON block at the very end, wrapped in ```json ... ```.

- Never mix JSON into the main text.



**Output Rules:**

- Never output raw JSON except in the final ```json``` block.

- Main body: natural flowing pastoral text (including Kingdom Challenge), then ONLY the clean JSON block.

- When referencing Scripture, CCC, saints, or documents, use accurate official URLs in Markdown [Text](url) pointing to the specific paragraph or section.

- For standard chat responses: follow the full core structure above.

- For **Delve Deeper** mode: follow the separate Delve Deeper rules — add new depth only; do not repeat the prior response or its citations.

''';



  static const String delveDeeperGuidelines = '''

**DELVE DEEPER MODE — NON-NEGOTIABLE (this is a follow-up, not a second answer to the same question):**

The user already received a full pastoral response. Delve Deeper must add **genuinely new** Catholic depth — not a longer restatement of what was already said.

**What to ADD (choose what fits; all must be NEW relative to the prior response):**
- **Different Scripture passages** that illuminate the topic from a fresh angle (OT wisdom, Psalms, Epistles, Gospel narratives not yet used).
- **More precise Catechism context** — adjacent paragraphs, related doctrine, sacramental or moral theology that goes further.
- **Theological nuance** — distinctions, common misconceptions, how Church teaching applies in hard cases.
- **Pastoral application** not already covered — concrete scenarios, habits of discernment, when to seek a priest or spiritual director.
- **Saints and holy lives (when they fit naturally):** Apply the same Saints guidance as standard responses. Delve Deeper is a good occasion for a saint example when one **clearly illuminates** the topic and was **not** already used in the prior response — but do not force multiple or obligatory mentions.

**What NOT to do:**
- **Do NOT** repeat, paraphrase, or summarize the prior response.
- **Do NOT** reuse the same Markdown links (same URL or same passage/paragraph label) already present in the prior response. The user message lists citations already used — treat them as off-limits for new links.
- **Do NOT** re-open with the same welcome, Two Great Commandments overview, or "What Would Jesus Do?" structure as if starting fresh.
- **Do NOT** copy the same Kingdom Challenge or suggestedActions — offer **distinct**, **varied-type** new challenges aligned with the deeper material (not the same Rosary/Mass/outreach template).

**Link rules for Delve Deeper:**
- Include **at least two NEW** accurate Markdown links the prior response did not use (Scripture, CCC, Vatican/USCCB, or official saint resources when available).
- If the best further reference is a paragraph already cited, mention it **by number only** (e.g. "see also CCC 2331") without repeating the same URL.
- Never invent links. Prefer BibleGateway (NABRE/RSVCE) and Vatican.va paragraph URLs.

**Structure (lighter than a first response — warm, pastoral, instructional):**
1. One brief sentence acknowledging this is deeper exploration (no first-person "I").
2. **Saints Who Lived This** (optional — only when a vivid saint example naturally fits and adds new depth not already covered).
3. **Further Light from Scripture and the Church** — new citations and teaching.
4. **Going Further in Your Situation** — fresh pastoral application.
5. **Kingdom Challenge** — one **new**, distinct, demanding actionable call (labeled clearly).
6. End with ONLY the ```json``` suggestedActions block (2–3 **new**, distinct actions; at least one outreach to another person; Church-correct frequencies).

**Tone:** Warm, encouraging, clear — same WWJD voice, no chat-persona "I".

''';



  static const String jsonBlockTemplate = '''

```json

{

  "suggestedActions": [

    {

      "title": "Offer Today's Work to God",

      "description": "Before beginning work or study tomorrow, pray one sentence offering the day's tasks to God for the good of others.",

      "frequency": "Daily"

    },

    {

      "title": "Listen Without Fixing",

      "description": "This week, give one friend or family member twenty minutes of undivided listening without offering advice unless asked.",

      "frequency": "Weekly"

    },

    {

      "title": "Gospel Before Screens",

      "description": "For the next three days, read one paragraph from the day's Gospel before opening social media or news.",

      "frequency": "Daily"

    }

  ]

}

```''';



  static const Set<String> _allowedFrequencies = {

    'Daily',

    'Weekly',

    'Once',

    'One-time',

    'Monthly',

  };



  /// Normalizes parsed suggestedActions for the Add to My Gifts Plan modal.

  static List<Map<String, String>> normalizeSuggestedActions(

    List<Map<String, dynamic>> raw,

  ) {

    final normalized = <Map<String, String>>[];



    for (final entry in raw) {

      var title = entry['title']?.toString().trim() ?? '';

      var description = entry['description']?.toString().trim() ?? '';

      var frequency = entry['frequency']?.toString().trim() ?? 'Daily';



      if (description.isEmpty && title.isNotEmpty) {

        description = title;

      }

      if (title.isEmpty && description.isNotEmpty) {

        title = _deriveTitleFromDescription(description);

      }

      if (title.isEmpty || description.isEmpty) continue;



      if (_titlesTooSimilar(title, description)) {

        title = _deriveTitleFromDescription(description);

      }



      frequency = _normalizeFrequency(frequency);



      normalized.add({

        'title': title,

        'description': description,

        'frequency': frequency,

      });

    }



    return normalized.take(3).toList();

  }

  /// Strips actions whose description is the full pastoral response (not a gift).
  static List<Map<String, String>> sanitizeGiftActions(
    List<Map<String, String>> actions,
    String responseText,
  ) {
    if (actions.isEmpty) return actions;

    final cleaned = actions.where((action) {
      final description = action['description'] ?? '';
      return !_descriptionLooksLikeFullResponse(description, responseText);
    }).toList();

    return cleaned;
  }

  /// Builds one actionable gift when JSON extraction fails.
  static List<Map<String, String>> buildFallbackGiftActions(
    String responseText, {
    String? userQuestion,
  }) {
    final kingdom = extractKingdomChallengeText(responseText);
    var description = kingdom ?? _firstActionableSentence(responseText);

    if (description == null || description.trim().isEmpty) {
      final question = userQuestion?.trim();
      if (question != null && question.isNotEmpty) {
        return normalizeSuggestedActions([
          {
            'title': _titleFromQuestion(question),
            'description':
                'Live out the guidance from your Seeking God\'s Wisdom session in daily life.',
            'frequency': 'Daily',
          },
        ]);
      }
      return [];
    }

    if (_descriptionLooksLikeFullResponse(description, responseText)) {
      description = _firstActionableSentence(responseText) ?? description;
    }

    return normalizeSuggestedActions([
      {
        'description': description.trim(),
        'frequency': 'Daily',
      },
    ]);
  }

  /// Extracts the Kingdom Challenge section for a concise gift description.
  static String? extractKingdomChallengeText(String responseText) {
    final patterns = [
      RegExp(
        r'\*\*Kingdom Challenge\*\*\s*:?\s*(.+?)(?=\n\s*\*\*|\n\s*#|\Z)',
        dotAll: true,
        caseSensitive: false,
      ),
      RegExp(
        r'(?:^|\n)\s*Kingdom Challenge\s*:?\s*(.+?)(?=\n\s*\*\*|\n\s*#|\Z)',
        dotAll: true,
        caseSensitive: false,
      ),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(responseText);
      if (match == null) continue;
      final text = _stripMarkdown(match.group(1)!.trim());
      if (text.length >= 12) return text;
    }
    return null;
  }

  static String? _firstActionableSentence(String responseText) {
    final stripped = _stripMarkdown(responseText);
    final sentences = stripped.split(RegExp(r'(?<=[.!?])\s+'));
    for (final sentence in sentences) {
      final trimmed = sentence.trim();
      if (trimmed.length < 12 || trimmed.length > 220) continue;
      if (RegExp(r'^(welcome|it is good|the church|scripture|catechism)',
              caseSensitive: false)
          .hasMatch(trimmed)) {
        continue;
      }
      if (RegExp(r'^(begin|try|consider|set aside|reach out|join|practice|commit to|pray|visit|call|fast|examine)',
              caseSensitive: false)
          .hasMatch(trimmed)) {
        return trimmed;
      }
    }
    return null;
  }

  static String _titleFromQuestion(String question) {
    final trimmed = question.trim();
    if (trimmed.length <= 55) return trimmed;
    return '${trimmed.substring(0, 52)}…';
  }

  static bool _descriptionLooksLikeFullResponse(
    String description,
    String fullResponse,
  ) {
    final desc = _stripMarkdown(description).trim().toLowerCase();
    final full = _stripMarkdown(fullResponse).trim().toLowerCase();
    if (desc.isEmpty || full.isEmpty) return false;
    if (desc == full) return true;
    if (desc.length > 280 && desc.length >= (full.length * 0.45)) return true;
    if (full.startsWith(desc) && desc.length >= (full.length * 0.65)) {
      return true;
    }
    return false;
  }

  static String _stripMarkdown(String text) {
    return text
        .replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'$1')
        .replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'$1')
        .replaceAll(RegExp(r'\*([^*]+)\*'), r'$1')
        .replaceAll(RegExp(r'`([^`]+)`'), r'$1')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Fast, bounded extraction for Add to My Gifts — avoids heavy regex on full responses.
  static List<Map<String, String>> extractSuggestedActionsFromResponse(String fullResponse) {
    final fenceStart = fullResponse.indexOf('```json');
    if (fenceStart != -1) {
      final contentStart = fenceStart + 7;
      final fenceEnd = fullResponse.indexOf('```', contentStart);
      if (fenceEnd != -1) {
        final parsed = _parseSuggestedActionsJson(
          fullResponse.substring(contentStart, fenceEnd).trim(),
        );
        if (parsed.isNotEmpty) return parsed;
      }
    }

    final jsonObject = _extractJsonObjectContaining(fullResponse, '"suggestedActions"');
    if (jsonObject != null) {
      final parsed = _parseSuggestedActionsJson(jsonObject);
      if (parsed.isNotEmpty) return parsed;
    }

    final tail = fullResponse.length > 2000
        ? fullResponse.substring(fullResponse.length - 2000)
        : fullResponse;
    final actionMatches = RegExp(
      r'(Begin|Try|Consider|Set aside|Reach out|Join|Practice|Commit to)[^.]{10,120}\.',
      caseSensitive: false,
    ).allMatches(tail);

    return normalizeSuggestedActions(
      actionMatches.take(3).map((m) {
        return {
          'description': m.group(0)!.trim(),
          'frequency': 'Daily',
        };
      }).toList(),
    );
  }

  /// Removes trailing suggestedActions JSON from visible chat text.
  static String stripSuggestedActionsJson(String fullResponse) {
    final fenceStart = fullResponse.indexOf('```json');
    if (fenceStart != -1) {
      return fullResponse.substring(0, fenceStart).trim();
    }

    final jsonObject = _extractJsonObjectContaining(fullResponse, '"suggestedActions"');
    if (jsonObject != null) {
      return fullResponse.replaceFirst(jsonObject, '').trim();
    }

    return fullResponse;
  }

  static List<Map<String, String>> _parseSuggestedActionsJson(String jsonStr) {
    try {
      final data = json.decode(jsonStr.replaceAll(RegExp(r'\s+'), ' ').trim());
      final list = data['suggestedActions'] as List?;
      if (list == null || list.isEmpty) return [];
      return normalizeSuggestedActions(
        list.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      );
    } catch (_) {
      return [];
    }
  }

  static String? _extractJsonObjectContaining(String text, String needle) {
    final idx = text.indexOf(needle);
    if (idx == -1) return null;

    final start = text.lastIndexOf('{', idx);
    if (start == -1) return null;

    var depth = 0;
    for (var i = start; i < text.length; i++) {
      final ch = text[i];
      if (ch == '{') depth++;
      if (ch == '}') {
        depth--;
        if (depth == 0) return text.substring(start, i + 1);
      }
    }
    return null;
  }



  static String _normalizeFrequency(String frequency) {

    final cleaned = frequency.trim();

    if (cleaned.toLowerCase() == 'once') return 'One-time';

    if (_allowedFrequencies.contains(cleaned)) {

      return cleaned == 'Once' ? 'One-time' : cleaned;

    }

    if (cleaned.toLowerCase().contains('week')) return 'Weekly';

    if (cleaned.toLowerCase().contains('month')) return 'Monthly';

    if (cleaned.toLowerCase().contains('one')) return 'One-time';

    return 'Daily';

  }



  static bool _titlesTooSimilar(String title, String description) {

    final t = title.toLowerCase().trim();

    final d = description.toLowerCase().trim();

    if (t.isEmpty || d.isEmpty) return false;

    if (t == d) return true;

    if (d.startsWith(t) && t.length >= (d.length * 0.65)) return true;

    if (t.startsWith(d) && d.length >= (t.length * 0.65)) return true;

    return false;

  }



  static String _deriveTitleFromDescription(String description) {

    final firstClause = description.split(RegExp(r'[.!?;—–-]')).first.trim();

    if (firstClause.length >= 8 && firstClause.length <= 55) {

      return firstClause;

    }



    final words = description.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

    if (words.length <= 6) return description;

    return words.take(5).join(' ');

  }



  /// Builds a user-message appendix listing gifts/actions to avoid repeating.
  static String buildVarietyAvoidanceContext({
    List<String> recentGiftSummaries = const [],
    List<String> sessionActionSummaries = const [],
  }) {
    if (recentGiftSummaries.isEmpty && sessionActionSummaries.isEmpty) {
      return '';
    }

    final buffer = StringBuffer('''
---

**VARIETY CONTEXT — maximize fresh Kingdom Challenges & suggestedActions:**

Do **not** repeat or lightly rephrase any activity below. Choose new types, wording, and concrete acts tied to this question.
''');

    if (recentGiftSummaries.isNotEmpty) {
      buffer.writeln('\n**Already in the user\'s Sharing My Gifts plan:**');
      for (final line in recentGiftSummaries.take(20)) {
        buffer.writeln(line);
      }
    }

    if (sessionActionSummaries.isNotEmpty) {
      buffer.writeln('\n**Already suggested in this conversation:**');
      for (final line in sessionActionSummaries.take(15)) {
        buffer.writeln(line);
      }
    }

    return buffer.toString();
  }

  static String enrichUserMessageWithVarietyContext(
    String userMessage,
    String varietyContext,
  ) {
    final appendix = varietyContext.trim();
    if (appendix.isEmpty) return userMessage;
    return '$userMessage\n$appendix';
  }

  static List<String> summarizeSuggestedActions(
    List<Map<String, String>> actions,
  ) {
    return actions
        .map((action) {
          final title = action['title']?.trim() ?? '';
          final description = action['description']?.trim() ?? '';
          if (title.isEmpty && description.isEmpty) return '';
          if (title.isEmpty) return '- $description';
          if (description.isEmpty) return '- $title';
          return '- $title: $description';
        })
        .where((line) => line.isNotEmpty)
        .toList();
  }

  /// Markdown link labels already used in a response (for Delve Deeper de-duplication).
  static List<String> extractUsedCitationLabels(String responseText) {
    final labels = <String>{};
    final linkPattern = RegExp(r'\[([^\]]+)\]\(([^)]+)\)');
    for (final match in linkPattern.allMatches(responseText)) {
      final label = match.group(1)?.trim();
      if (label != null && label.isNotEmpty) {
        labels.add(label);
      }
    }
    return labels.toList();
  }

  /// System prompt for Delve Deeper API calls.
  static String forDelveDeeperSystem({required String timeContext}) {
    return '''You are the WWJD app voice — a faithful Catholic guide. You are not a person or chat companion. Never use first-person "I".

$delveDeeperGuidelines

**Voice & Person:** Never first-person "I". Address the user as **you**. Warm and pastoral, not conversational small talk.

**Sharing My Gifts (suggestedActions JSON):** Same rules as main chat — 2–3 distinct actions, at least one outreach to another person, Church-correct frequencies, clean ```json``` block at the very end only.

Current time: $timeContext.''';
  }

  /// User message for Delve Deeper — includes prior response and citations to avoid.
  static String forDelveDeeper({
    required String userTopic,
    required String previousResponse,
    String varietyContext = '',
  }) {
    final prior = previousResponse.trim();
    final truncatedPrior = prior.length > 8000
        ? '${prior.substring(0, 8000)}\n\n[…prior response truncated for length…]'
        : prior;
    final usedCitations = extractUsedCitationLabels(prior);
    final citationBlock = usedCitations.isEmpty
        ? '(none detected — still provide fresh citations)'
        : usedCitations.map((c) => '- $c').join('\n');
    final priorActions = summarizeSuggestedActions(
      extractSuggestedActionsFromResponse(prior),
    );
    final priorActionsBlock = priorActions.isEmpty
        ? '(none parsed — still provide wholly new suggestedActions)'
        : priorActions.map((a) => a).join('\n');

    return '''DELVE DEEPER REQUEST

**Original question:**
$userTopic

**Prior WWJD response (ALREADY GIVEN — do not repeat, paraphrase, or summarize):**
---
$truncatedPrior
---

**Citations / links already used above (DO NOT reuse these URLs or labels):**
$citationBlock

**Kingdom Challenge / suggestedActions from prior response (DO NOT repeat or lightly rephrase):**
$priorActionsBlock

Apply all Delve Deeper rules. Add new Scripture, new Catechism context, fresh pastoral application, and saint examples only when they fit naturally. End with the ```json``` suggestedActions block — **wholly new** actions, varied types, time-bound when possible.

${varietyContext.trim().isEmpty ? '' : varietyContext.trim()}

$jsonBlockTemplate''';
  }



  /// Main Seeking God's Wisdom system prompt.

  static String forChat({required String timeContext}) {

    return '''You are the WWJD app voice — a faithful Catholic guide that presents God's teaching and Church wisdom to individuals and this faith community. You are not a person, spiritual director, or chat companion. Never use first-person "I".



$criticalGuidelines



Current time: $timeContext.



Apply the core structure naturally in flowing paragraphs. Directly address the user's specific situation without first-person voice. Include the required **Kingdom Challenge** section — **formed to the topic of their question** whenever possible.



**FINAL OUTPUT RULE (MUST FOLLOW):**

1. Write your full pastoral response in natural paragraphs (with Kingdom Challenge included).

2. Include **at least one Markdown link** `[Text](url)` in the body (Scripture + CCC strongly preferred). Responses without links are invalid.

3. After your final paragraph, output ONLY a valid JSON block wrapped in ```json ... ```. Nothing else after it.

4. The JSON must contain 2–3 **varied, non-repetitive** suggestedActions with Church-correct frequencies **and at least one outreach action toward another person** (friend, family, stranger, poor, homeless, lonely, etc.). Maximize diversity — avoid patterns already in recent Gifts or this conversation.



End with exactly this shape (replace with situation-specific titles and descriptions):



$jsonBlockTemplate''';

  }

}

