/// A well-known Catholic prayer or short liturgical text with canonical wording.
class CatholicPrayer {
  const CatholicPrayer({
    required this.id,
    required this.displayName,
    required this.aliases,
    required this.body,
    this.attribution,
  });

  final String id;
  final String displayName;
  final List<String> aliases;
  final String body;
  final String? attribution;
}

/// Canonical Catholic prayers — fixed texts, not AI-generated.
class CatholicPrayerCatalog {
  CatholicPrayerCatalog._();

  static const List<CatholicPrayer> prayers = [
    CatholicPrayer(
      id: 'our_father',
      displayName: 'Our Father',
      aliases: [
        'our father',
        'lords prayer',
        "lord's prayer",
        'pater noster',
      ],
      body: '''Our Father, who art in heaven,
hallowed be thy name;
thy kingdom come;
thy will be done on earth as it is in heaven.
Give us this day our daily bread;
and forgive us our trespasses
as we forgive those who trespass against us;
and lead us not into temptation,
but deliver us from evil.
Amen.''',
    ),
    CatholicPrayer(
      id: 'hail_mary',
      displayName: 'Hail Mary',
      aliases: ['hail mary', 'ave maria'],
      body: '''Hail Mary, full of grace, the Lord is with thee.
Blessed art thou among women,
and blessed is the fruit of thy womb, Jesus.
Holy Mary, Mother of God,
pray for us sinners,
now and at the hour of our death.
Amen.''',
    ),
    CatholicPrayer(
      id: 'glory_be',
      displayName: 'Glory Be',
      aliases: [
        'glory be',
        'glory be to the father',
        'doxology',
      ],
      body: '''Glory be to the Father,
and to the Son,
and to the Holy Spirit.
As it was in the beginning,
is now, and ever shall be,
world without end.
Amen.''',
    ),
    CatholicPrayer(
      id: 'memorare',
      displayName: 'Memorare',
      aliases: ['memorare'],
      body: '''Remember, O most gracious Virgin Mary,
that never was it known
that anyone who fled to thy protection,
implored thy help,
or sought thy intercession,
was left unaided.
Inspired by this confidence,
I fly unto thee, O Virgin of virgins, my Mother.
To thee do I come, before thee I stand, sinful and sorrowful.
O Mother of the Word Incarnate,
despise not my petitions,
but in thy mercy hear and answer me.
Amen.''',
      attribution: 'Traditionally attributed to St. Bernard of Clairvaux.',
    ),
    CatholicPrayer(
      id: 'angelus',
      displayName: 'Angelus',
      aliases: ['angelus', 'the angelus'],
      body: '''V. The Angel of the Lord declared unto Mary.
R. And she conceived of the Holy Spirit.

Hail Mary...

V. Behold the handmaid of the Lord.
R. Be it done unto me according to thy word.

Hail Mary...

V. And the Word was made flesh.
R. And dwelt among us.

Hail Mary...

V. Pray for us, O holy Mother of God.
R. That we may be made worthy of the promises of Christ.

Let us pray:
Pour forth, we beseech thee, O Lord, thy grace into our hearts; that we, to whom the Incarnation of Christ, thy Son, was made known by the message of an angel, may by his Passion and Cross be brought to the glory of his Resurrection. Through the same Christ our Lord. Amen.''',
      attribution:
          'At each “Hail Mary…” above, pray the full Hail Mary. '
          'Traditionally prayed at 6 a.m., noon, and 6 p.m.',
    ),
    CatholicPrayer(
      id: 'act_of_contrition',
      displayName: 'Act of Contrition',
      aliases: [
        'act of contrition',
        'prayer of contrition',
      ],
      body: '''O my God, I am heartily sorry for having offended Thee,
and I detest all my sins because of thy just punishments,
but most of all because they offend Thee, my God,
who art all good and deserving of all my love.
I firmly resolve, with the help of Thy grace,
to sin no more and to avoid the near occasion of sin.
Amen.''',
    ),
    CatholicPrayer(
      id: 'anima_christi',
      displayName: 'Anima Christi',
      aliases: ['anima christi', 'soul of christ'],
      body: '''Soul of Christ, sanctify me.
Body of Christ, save me.
Blood of Christ, inebriate me.
Water from the side of Christ, wash me.
Passion of Christ, strengthen me.
O good Jesus, hear me.
Within thy wounds hide me.
Permit me not to be separated from thee.
From the wicked foe defend me.
At the hour of my death call me
and bid me come to thee,
that with thy saints I may praise thee
forever and ever.
Amen.''',
    ),
    CatholicPrayer(
      id: 'salve_regina',
      displayName: 'Hail, Holy Queen (Salve Regina)',
      aliases: [
        'salve regina',
        'hail holy queen',
        'hail, holy queen',
      ],
      body: '''Hail, holy Queen, Mother of Mercy,
our life, our sweetness, and our hope.
To thee do we cry, poor banished children of Eve;
to thee do we send up our sighs,
mourning and weeping in this valley of tears.
Turn then, most gracious advocate,
thine eyes of mercy toward us,
and after this our exile,
show unto us the blessed fruit of thy womb, Jesus.
O clement, O loving, O sweet Virgin Mary.
Amen.''',
    ),
    CatholicPrayer(
      id: 'apostles_creed',
      displayName: 'Apostles\' Creed',
      aliases: [
        'apostles creed',
        "apostle's creed",
      ],
      body: '''I believe in God,
the Father almighty,
Creator of heaven and earth,
and in Jesus Christ, his only Son, our Lord,
who was conceived by the Holy Spirit,
born of the Virgin Mary,
suffered under Pontius Pilate,
was crucified, died and was buried;
he descended into hell;
on the third day he rose again from the dead;
he ascended into heaven,
and is seated at the right hand of God the Father almighty;
from there he will come to judge the living and the dead.

I believe in the Holy Spirit,
the holy catholic Church,
the communion of saints,
the forgiveness of sins,
the resurrection of the body,
and life everlasting.
Amen.''',
      attribution: 'The Apostles\' Creed — a foundational profession of the Catholic faith.',
    ),
    CatholicPrayer(
      id: 'prayer_to_st_michael',
      displayName: 'Prayer to St. Michael the Archangel',
      aliases: [
        'st michael prayer',
        'saint michael prayer',
        'prayer to st michael',
        'prayer to saint michael',
      ],
      body: '''St. Michael the Archangel,
defend us in battle.
Be our protection against the wickedness and snares of the devil.
May God rebuke him, we humbly pray,
and do thou, O Prince of the heavenly hosts,
by the power of God,
cast into hell Satan and all the evil spirits
who prowl about the world seeking the ruin of souls.
Amen.''',
    ),
    CatholicPrayer(
      id: 'regina_caeli',
      displayName: 'Regina Caeli',
      aliases: [
        'regina caeli',
        'queen of heaven rejoice',
      ],
      body: '''V. Queen of Heaven, rejoice, alleluia.
R. For he whom you merited to bear, alleluia,
has risen, as he said, alleluia.
V. Pray for us to God, alleluia.
R. Rejoice and be glad, O Virgin Mary, alleluia.
V. For the Lord has truly risen, alleluia.

Let us pray:
O God, who through the resurrection of your Son, our Lord Jesus Christ,
granted joy to the whole world,
grant, we pray, that through his Mother, the Virgin Mary,
we may obtain the joys of everlasting life.
Through the same Christ our Lord. Amen.''',
      attribution:
          'Traditionally prayed during the Easter season in place of the Angelus.',
    ),
    CatholicPrayer(
      id: 'come_holy_spirit',
      displayName: 'Come, Holy Spirit',
      aliases: [
        'come holy spirit',
        'veni sancte spiritus',
        'holy spirit prayer',
      ],
      body: '''Come, Holy Spirit, fill the hearts of your faithful
and kindle in them the fire of your love.
Send forth your Spirit and they shall be created.
And you shall renew the face of the earth.

Let us pray:
O God, who by the light of the Holy Spirit
did instruct the hearts of the faithful,
grant us in the same Spirit to be truly wise
and ever to rejoice in his consolation.
Through Christ our Lord. Amen.''',
    ),
    CatholicPrayer(
      id: 'guardian_angel',
      displayName: 'Guardian Angel Prayer',
      aliases: [
        'guardian angel prayer',
        'angel of god',
        'angel of god my guardian dear',
      ],
      body: '''Angel of God, my guardian dear,
to whom God's love commits me here,
ever this day be at my side,
to light and guard, to rule and guide.
Amen.''',
    ),
    CatholicPrayer(
      id: 'morning_offering',
      displayName: 'Morning Offering',
      aliases: [
        'morning offering',
        'daily offering',
      ],
      body: '''O Jesus, through the Immaculate Heart of Mary,
I offer you my prayers, works, joys, and sufferings of this day
for all the intentions of your Sacred Heart,
in union with the Holy Sacrifice of the Mass throughout the world,
in reparation for my sins, for the intentions of all my associates,
and in particular for the intentions of our Holy Father.
Amen.''',
    ),
    CatholicPrayer(
      id: 'grace_before_meals',
      displayName: 'Grace Before Meals',
      aliases: [
        'grace before meals',
        'bless us o lord',
        'meal prayer',
        'table grace',
      ],
      body: '''Bless us, O Lord, and these thy gifts,
which we are about to receive from thy bounty,
through Christ our Lord.
Amen.''',
    ),
    CatholicPrayer(
      id: 'sign_of_the_cross',
      displayName: 'Sign of the Cross',
      aliases: [
        'sign of the cross',
        'make the sign of the cross',
      ],
      body: '''In the name of the Father,
and of the Son,
and of the Holy Spirit.
Amen.''',
      attribution: 'Made with the right hand: forehead, chest, left shoulder, right shoulder.',
    ),
    CatholicPrayer(
      id: 'eternal_rest',
      displayName: 'Eternal Rest (Requiem Prayer)',
      aliases: [
        'eternal rest',
        'requiem prayer',
        'prayer for the dead',
      ],
      body: '''Eternal rest grant unto them, O Lord,
and let perpetual light shine upon them.
May they rest in peace.
Amen.''',
    ),
    CatholicPrayer(
      id: 'holy_rosary',
      displayName: 'Holy Rosary — Mysteries & Instructions',
      aliases: [
        'holy rosary',
        'rosary',
        'how to pray the rosary',
        'rosary mysteries',
        'joyful mysteries',
        'sorrowful mysteries',
        'glorious mysteries',
        'luminous mysteries',
      ],
      body: '''HOW TO PRAY THE ROSARY

The Rosary is a treasured devotion in which we meditate on the life of Jesus Christ through the eyes of Mary. Each Rosary consists of five decades. On each decade, we announce a mystery, pray one Our Father, ten Hail Marys, and one Glory Be.

Begin:
1. Make the Sign of the Cross.
2. Pray the Apostles' Creed (on the crucifix or first large bead).
3. Pray one Our Father (on the first large bead).
4. Pray three Hail Marys for faith, hope, and charity (on the next three beads).
5. Pray one Glory Be.

For each of the five decades:
1. Announce the mystery.
2. Pray one Our Father.
3. Pray ten Hail Marys while meditating on the mystery.
4. Pray one Glory Be.
5. Optional: O my Jesus, forgive us our sins, save us from the fires of hell, lead all souls to heaven, especially those in most need of thy mercy.

After the five decades:
Pray the Hail, Holy Queen (Salve Regina).

Optional closing:
O God, whose only-begotten Son, by his life, death, and resurrection, has purchased for us the rewards of eternal life, grant, we beseech thee, that while meditating upon these mysteries of the most holy Rosary of the Blessed Virgin Mary, we may imitate what they contain and obtain what they promise, through the same Christ our Lord. Amen.

---

THE JOYFUL MYSTERIES
(Traditionally prayed on Monday and Saturday; Sunday in Advent and Christmas)

1. The Annunciation — The Angel Gabriel announces to Mary that she will bear the Son of God.
2. The Visitation — Mary visits her cousin Elizabeth; John the Baptist leaps for joy in the womb.
3. The Nativity — Jesus is born in Bethlehem.
4. The Presentation — Mary and Joseph present Jesus in the Temple.
5. The Finding in the Temple — The child Jesus is found teaching in the Temple.

---

THE SORROWFUL MYSTERIES
(Traditionally prayed on Tuesday and Friday)

1. The Agony in the Garden — Jesus prays in Gethsemane and accepts the cup of suffering.
2. The Scourging at the Pillar — Jesus is cruelly whipped.
3. The Crowning with Thorns — Jesus is mocked and crowned with thorns.
4. The Carrying of the Cross — Jesus carries the Cross to Calvary.
5. The Crucifixion — Jesus dies on the Cross for our salvation.

---

THE GLORIOUS MYSTERIES
(Traditionally prayed on Wednesday and Sunday)

1. The Resurrection — Jesus rises from the dead.
2. The Ascension — Jesus ascends into heaven.
3. The Descent of the Holy Spirit — The Holy Spirit comes upon the Apostles at Pentecost.
4. The Assumption — Mary is taken body and soul into heaven.
5. The Coronation — Mary is crowned Queen of Heaven and earth.

---

THE LUMINOUS MYSTERIES
(Traditionally prayed on Thursday; instituted by Pope St. John Paul II)

1. The Baptism of Jesus in the Jordan — The Father declares, "This is my beloved Son."
2. The Wedding at Cana — Jesus performs his first miracle at Mary's request.
3. The Proclamation of the Kingdom — Jesus calls all to repentance and announces the Good News.
4. The Transfiguration — Jesus is revealed in glory on Mount Tabor.
5. The Institution of the Eucharist — Jesus gives us his Body and Blood in the Holy Sacrifice of the Mass.''',
      attribution:
          'The Our Father, Hail Mary, Glory Be, Apostles\' Creed, and Hail, Holy Queen '
          'are also available separately in this prayer library.',
    ),
    CatholicPrayer(
      id: 'benediction',
      displayName: 'Benediction of the Blessed Sacrament',
      aliases: [
        'benediction',
        'benediction of the blessed sacrament',
        'eucharistic adoration benediction',
        'o salutaris hostia',
        'tantum ergo',
        'divine praises',
        'prayers for benediction',
      ],
      body: '''These are the standard prayers commonly prayed during Benediction of the Blessed Sacrament and Eucharistic Adoration.

---

O SALUTARIS HOSTIA (O Saving Victim)

O saving Victim, open wide
The gate of heaven to us below;
Our foes press on from every side;
Your aid supply, your strength bestow.

To your great name be endless praise,
Immortal Godhead, One in Three;
Oh, grant us endless length of days,
In our true native land with thee.
Amen.

---

TANTUM ERGO

Down in adoration falling,
Lo! the sacred Host we hail;
Lo! o'er ancient forms departing,
Newer rites of grace prevail;
Faith for all defects supplying,
Where the feeble senses fail.

To the everlasting Father,
And the Son who reigns on high,
With the Holy Spirit proceeding
Forth from each eternally,
Be salvation, honor, blessing,
Might and endless majesty.
Amen.

V. You have given them bread from heaven.
R. Containing in itself all sweetness.

Let us pray:
O God, who in this wonderful Sacrament left us a memorial of your Passion, grant us, we pray, so to venerate the sacred mysteries of your Body and Blood that we may ever feel within ourselves the fruits of your redemption. Who live and reign for ever and ever.
R. Amen.

---

THE DIVINE PRAISES

Blessed be God.
Blessed be his Holy Name.
Blessed be Jesus Christ, true God and true Man.
Blessed be the Name of Jesus.
Blessed be his Most Sacred Heart.
Blessed be his Most Precious Blood.
Blessed be Jesus in the Most Holy Sacrament of the Altar.
Blessed be the Holy Spirit, the Paraclete.
Blessed be the great Mother of God, Mary most Holy.
Blessed be her Holy and Immaculate Conception.
Blessed be her Glorious Assumption.
Blessed be the name of Mary, Virgin and Mother.
Blessed be Saint Joseph, her most chaste spouse.
Blessed be God in his Angels and in his Saints.

---

CLOSING PRAYER

May the Heart of Jesus, in the Most Blessed Sacrament,
be praised, adored, and loved with grateful affection,
at every moment, in all the tabernacles of the world,
even to the end of time.
Amen.''',
      attribution:
          'Traditional prayers of Eucharistic Adoration and Benediction in the Roman Rite.',
    ),
    CatholicPrayer(
      id: 'litany_of_the_saints',
      displayName: 'Litany of the Saints',
      aliases: [
        'litany of the saints',
        'litany of saints',
        'saints litany',
      ],
      body: '''At each invocation, the leader prays the first line and the people respond: "Pray for us."

Lord, have mercy. R. Lord, have mercy.
Christ, have mercy. R. Christ, have mercy.
Lord, have mercy. R. Lord, have mercy.

Christ, hear us. R. Christ, graciously hear us.
God the Father of heaven, R. have mercy on us.
God the Son, Redeemer of the world, R. have mercy on us.
God the Holy Spirit, R. have mercy on us.
Holy Trinity, one God, R. have mercy on us.

Holy Mary, R. pray for us.
Holy Mother of God, R. pray for us.
Holy Virgin of virgins, R. pray for us.
Saint Michael, R. pray for us.
Saint Gabriel, R. pray for us.
Saint Raphael, R. pray for us.
All you holy Angels and Archangels, R. pray for us.
All you holy orders of Angels, R. pray for us.
Saint John the Baptist, R. pray for us.
Saint Joseph, R. pray for us.
All you holy Patriarchs and Prophets, R. pray for us.
Saint Peter, R. pray for us.
Saint Paul, R. pray for us.
Saint Andrew, R. pray for us.
Saint James, R. pray for us.
Saint John, R. pray for us.
Saint Thomas, R. pray for us.
Saint James, R. pray for us.
Saint Philip, R. pray for us.
Saint Bartholomew, R. pray for us.
Saint Matthew, R. pray for us.
Saint Simon, R. pray for us.
Saint Jude, R. pray for us.
Saint Matthias, R. pray for us.
Saint Barnabas, R. pray for us.
Saint Luke, R. pray for us.
Saint Mark, R. pray for us.
All you holy Apostles and Evangelists, R. pray for us.
All you holy Disciples of the Lord, R. pray for us.
All you holy Innocents, R. pray for us.
Saint Stephen, R. pray for us.
Saint Lawrence, R. pray for us.
Saint Vincent, R. pray for us.
Saint Fabian, R. pray for us.
Saint Sebastian, R. pray for us.
All you holy Martyrs, R. pray for us.
Saint Gregory, R. pray for us.
Saint Ambrose, R. pray for us.
Saint Augustine, R. pray for us.
Saint Jerome, R. pray for us.
All you holy Doctors of the Church, R. pray for us.
Saint Anthony, R. pray for us.
Saint Benedict, R. pray for us.
Saint Bernard, R. pray for us.
Saint Dominic, R. pray for us.
Saint Francis, R. pray for us.
All you holy Priests and Religious, R. pray for us.
Saint Mary Magdalene, R. pray for us.
Saint Agnes, R. pray for us.
Saint Cecilia, R. pray for us.
Saint Agatha, R. pray for us.
Saint Anastasia, R. pray for us.
All you holy Virgins and Widows, R. pray for us.
All you holy Men and Women, R. pray for us.

Lamb of God, you take away the sins of the world, R. spare us, O Lord.
Lamb of God, you take away the sins of the world, R. graciously hear us, O Lord.
Lamb of God, you take away the sins of the world, R. have mercy on us.

Let us pray:
Almighty and eternal God, who by your grace have made us partakers of so great a cloud of witnesses, grant, we pray, that we may be found worthy to rejoice in their fellowship for ever in heaven. Through Christ our Lord.
R. Amen.''',
      attribution:
          'Standard form of the Litany of the Saints from the Roman Rite. '
          'Additional saints may be inserted as permitted by liturgical law.',
    ),
  ];

  /// Prayers sorted alphabetically by common English title.
  static List<CatholicPrayer> get sortedByTitle {
    final copy = List<CatholicPrayer>.from(prayers);
    copy.sort((a, b) => a.displayName.compareTo(b.displayName));
    return copy;
  }

  static CatholicPrayer? byId(String id) {
    for (final prayer in prayers) {
      if (prayer.id == id) return prayer;
    }
    return null;
  }

  /// Filter prayers by title or alias (case-insensitive).
  static List<CatholicPrayer> search(String query) {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) return sortedByTitle;

    return sortedByTitle.where((prayer) {
      if (prayer.displayName.toLowerCase().contains(trimmed)) return true;
      for (final alias in prayer.aliases) {
        if (alias.contains(trimmed)) return true;
      }
      return false;
    }).toList();
  }
}
