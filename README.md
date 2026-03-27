# PopAuras

PopAuras is a World of Warcraft addon for Retail.

It helps you show important things on your screen with bars and icons.
You can use it for spell cooldowns, buffs, debuffs, casts, timers, and kick tracking.

It is kind of like WeakAuras, but this addon is built to be simple and steady.

## What This Addon Does

PopAuras lets you make little trackers that pop up when something matters.

You can make:

- Icons
- Bars
- Groups
- Dynamic Groups
- Interrupt Trackers

## Aura Types

These are the main things you can make:

### Icon Aura

This shows a spell or thing as an icon.

Good for:

- Spell cooldowns
- Item cooldowns
- Buffs
- Debuffs

### Bar Aura

This shows a bar that fills or drains.

Good for:

- Cooldowns
- Buff timers
- Debuff timers
- Cast timers

### Group

A group is a holder for other auras.
It helps you keep things together.

### Dynamic Group

A dynamic group is like a smart group.
It can line things up for you as they show and hide.

### Interrupt Tracker

This is made for kicks and interrupts.
It can help show who has a kick ready and who does not.

## Trigger Types

These are the things that can make an aura show up:

- Simple: always, in combat, or when you have a target
- Aura: buffs or debuffs
- Spell Cooldown: tracks a spell cooldown
- Item Cooldown: tracks an item cooldown
- Cast / Channel: tracks a cast bar or channel
- Internal Timer: tracks a timer inside the addon

## How To Open It In Game

Type this in chat:

```text
/pa
```

You can also use:

```text
/popauras
```

## How To Install It

If you are on WoW Retail, put the `PopaAuras` folder in your `AddOns` folder.

The normal path looks like this:

```text
World of Warcraft\_retail_\Interface\AddOns\PopaAuras
```

Do not put it in the `WTF` folder.
`WTF` is for saved settings.
The addon files go in `Interface\AddOns`.

## Easy Install Steps

1. Close World of Warcraft.
2. Open your WoW folder.
3. Open `_retail_`.
4. Open `Interface`.
5. Open `AddOns`.
6. Put the `PopaAuras` folder inside `AddOns`.
7. Start WoW again.
8. At the character screen, make sure the addon is turned on.

When you are done, this folder should exist:

```text
World of Warcraft\_retail_\Interface\AddOns\PopaAuras
```

And inside that folder, you should see files like:

```text
PopaAuras.toc
PopAuras.lua
Core\
Data\
Engine\
Renderers\
Triggers\
UI\
Util\
```

## First Time Use

After you log in:

1. Type `/pa`
2. Make a new icon or bar
3. Pick what you want to track
4. Move it where you want

## Good Examples

Here are easy things to make:

- A bar for a spell cooldown
- An icon for a proc buff
- A bar for a target debuff
- A cast bar for an enemy spell
- An interrupt tracker for dungeon kicks

## Notes

This addon is for WoW Retail.
It is made to be safe and reliable.
It tries to track things in a clean way without weird old addon tricks.
