-- map
--   Command name
--     item name
--        item info
local map={}
map.warp={
  ['Warp Ring']={id=28540,japanese='デジョンリング',english="Warp Ring",slot='ring'},
  ['Warp Cudgel']={id=17040,japanese='デジョンカジェル',english="Warp Cudgel",slot='main'},
  ['Instant Warp']={id=4181,japanese='呪符デジョン',english="Instant Warp"},
}
map.dem={
  ["Dim. Ring (Dem)"]={id=26177,japanese='Ｄ．デムリング',english="Dim. Ring (Dem)",slot='ring'},
}
map.holla={
  ["Dim. Ring (Holla)"]={id=26176,japanese='Ｄ．ホラリング',english="Dim. Ring (Holla)",slot='ring'},
}
map.mea={
  ["Dim. Ring (Mea)"]={id=26178,japanese='Ｄ．メアリング',english="Dim. Ring (Mea)",slot='ring'},
}
map.dimmer={
  ["Dim. Ring (Dem)"]={id=26177,japanese='Ｄ．デムリング',english="Dim. Ring (Dem)",slot='ring'},
  ["Dim. Ring (Holla)"]={id=26176,japanese='Ｄ．ホラリング',english="Dim. Ring (Holla)",slot='ring'},
  ["Dim. Ring (Mea)"]={id=26178,japanese='Ｄ．メアリング',english="Dim. Ring (Mea)",slot='ring'},
}
map.dim=map.dimmer

map.rr={
  -- reraise 1
  ["Instant Reraise"]={id=4182,english="Instant Reraise",japanese="呪符リレイズ",},
  ["Reraise Earring"]={id=14790,english="Reraise Earring",japanese="リレイズピアス",slot='earring'},
  ["Raising Earring"]={id=16003,english="Raising Earring",japanese="レイジングピアス",slot='earring'},
  ["Reraise Ring"]={id=26169,english="Reraise Ring",japanese="リレイズリング",slot='ring'},
  ["Wh. Rarab Cap +1"]={id=25679,english="Wh. Rarab Cap +1",japanese="白ララブキャップ+1",slot='head'},
  ["Reraiser"]={id=4172,en="Reraiser",ja="リレイザー",enl="reraiser",},
  ["Scapegoat"]={id=5412,en="Scapegoat",ja="スケープゴート"},
  -- reraise 2
  ["Reraise Gorget"]={id=13171,en="Reraise Gorget",ja="リレイズゴルゲット",slot='neck'},
  ["Reraise Hairpin"]={id=15211,en="Reraise Hairpin",ja="蘇生の髪飾り",slot='head'},
  ["Kocco's Earring"]={id=15998,en="Kocco's Earring",ja="コッコのピアス",slot='earring'},
  ["Hi-Reraiser"]={id=4173,en="Hi-Reraiser",ja="ハイリレイザー",},
  ["Revive Feather"]={id=5258,en="Revive Feather",ja="リバイヴフェザー",},
  -- reraise 3
  ["Raphael's Rod"]={id=18398,en="Raphael's Rod",ja="ラファエルロッド",slot='main'},
  ["Mamool Ja Earring"]={id=16012,en="Mamool Ja Earring",ja="マムージャピアス",slot='ear'},
  ["Airmid's Gorget"]={id=10963,en="Airmid's Gorget",ja="エアミドゴルゲット",slot='neck'},
  ["Super Reraiser"]={id=5770,en="Super Reraiser",ja="スーパーリレイザー",},
  ["Rebirth Feather"]={id=5259,en="Rebirth Feather",ja="リバースフェザー",},
  ["Dusty Reraise"]={id=5436,en="Dusty Reraise",ja="ダスティリレイズ",},
  -- reraise 5
  ["Pandit's Staff"]={id=22101,en="Pandit's Staff",ja="賢者の杖",slot='main'},
}

return map 