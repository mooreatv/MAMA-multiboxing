<img src="https://raw.githubusercontent.com/mooreatv/Mama/master/Mama_icon.png" height=64 width=64 align=right>

## About M.A.M.A. Multiboxing

MAMA is an open-source MultiBoxing (dual-boxing) addon with the following design goals:

- Opensource license (so if the current author gets hit by a bus, anyone else can pick it up and/or make improvements)

- High quality code

- Minimal dependencies

- Low footprint (both memory and cpu and addon chatter)

- Works with a single code base on both Wow Classic and regular (SL as of this writing)

- Let's you have dynamic teams with or without ISBoxer

**M.A.M.A.** stands for **M**ooreaTv's/minimal yet **A**wesome **M**ultiboxing **A**ssistant in reverence to grandfather of all (good) multi-boxing addons: _Jamba_ (Jafula's Awesome MultiBoxing Assistant), which also inspired the _EMA_ name.

Optionally: have a look at [WowOpenBox.org](https://WowOpenBox.org/) for the only open-source windows multiboxing software verifiably compliant with Blizzard's new rules.

## What does it do ?

**M.A.M.A relies on my DynamicBoxer for core team communication functionality**

- Let's you use DynamicBoxer without requiring ISBoxer (with WOB, but also works with ISBoxer as alternative to EMA), including fast in order invite/disband, EMA sync etc... just set your window slot # in the options panel or with `/mama s N`.

- Let's you keybind or slash command "promoteme" (`/mama l` to make a new lead)

- add `/click MamaAssist` in front of your macro to assist whoever you are leading with. (you can `/mama lead othertoon` to assist another character like a tank when it's not your own/you joined another party)

- or `/click MamaTrain` for a follow train + assist (keybindable too), `/click MamaFollow` for just follow and assist of the lead (keybindable too)

- `/mama mount` and `/mama mount dismount` and keybindings for mounting/dismounting as a team. Note that only dismount works in classic.

- Set EMA master when setting group lead (if EMA is installed and config checkbox is on, but `/click MamaAssist` is faster and more reliable)

- Set loot to free for all (and back to group when inviting extra)

- Share/accept quests on minions, Abandon quests as a team.

- Take same flight path as your team

- and more coming quite often... see `/mama` and `/mama config` and keybindings.

- **Note** that on Wrath of the Lich King, and now in Dragonflight and now even on Classic (hardcore and era) where FollowUnit() has been hardware protected by Blizzard; `followme` and `alltogether` keybinds won't work. Please instead use `/mama lead` (once/when changing lead) and `/click MamaFollow` or the keybind for it on all. `/click MamaFollow` will also do the `MamaAssist` in addition to following so you can do both in 1 key. Ditto now with `MamaTrain`

On legacy:

- Used to let you keybind or slash command "followme" (`/mama f` this stopped working even on classic from 1.14.4)

- `/mama altogether` and keybinding to do both "follow me" and "make me lead" in one efficient command. (1 addon message).


_Input on feature prioritization is most welcome!_

Mama might eventually also ensure your multiboxing or dual boxing team can do stuff like:

- Auto vendor/repair

- And more features per your request(s) !

Mama works well in conjunction with ISBoxer and DynamicBoxer but also with other multiboxing software or hardware

## Setup

As mentioned above there is a one time setup/pairing with DynamicBoxer:

`/mama s 1` in window 1, `/mama s 2` in window 2, `/mama s 3` in window 3 etc... then copy the token from dynamicboxer window 1 and paste in the other windows. Type return after `Ctrl-C` (copy) from window1 then paste `Ctrl-V` in all other windows as prompted. It may take a `/reload` the first time to complete the one time setup.

Set in game keybind for "mama alltogether" so you can trigger both follow me and make leader in 1 key/addon message. (and the other commands too)

Add `/click MamaAssist` in front of your macro to assist whoever you are leading with.

If you see anything red in the dbox-mama blue status window: something is wrong! try `/reload` and read the messages in the chat window if it persists. Repeat the setup carefully (`/dbox show` if you closed the dialog) and if that still doesn't work come to discord.

## More info

Get the binary release using curse/twitch/overwolf/... clients
https://www.curseforge.com/wow/addons/mama-multiboxing

You will also need https://www.curseforge.com/wow/addons/dynamicboxer

The source of the addon resides on https://github.com/mooreatv/MAMA-multiboxing
(and the MoLib library at https://github.com/mooreatv/MoLib)

Releases detail/changes are on https://github.com/mooreatv/MAMA-multiboxing/releases
