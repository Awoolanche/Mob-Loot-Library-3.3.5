# Mod Loot Library (MLL)
A WoW 3.3.5 add-on introducing a searchable library of creatures, items and crafting recipes, showing where things drop or are sold, what crafts what, and who teaches it. Data generated from AzerothCore.

### Installation
Requirements: WoW WoTLK 3.3.5 client, Python 3.

1. Create a `MobLoot` folder in in your WoW instance's addon folder, eg. `World of Warcraft\Interface\AddOns\MobLoot\`.
2. Put `MobLoot.toc`, `MobLoot.lua` and `gen_mobloot_data.py` inside the `MobLoot` folder.
3. The add-on is ready to use, but doesn't contain any data yet. Run `gen_mobloot_data.py` to generate it from AzerothCore repository.
4. Once the client is launched, the add-on should appear on the add-on list.

### Usage
- Click the minimap button or the button on your target's portrait to see the loot table of your target.
- Right-click either button, or type /mobloot, to search the library.
- Drag either button to move it.
 
    <img width="270" height="280" alt="obraz" src="https://github.com/user-attachments/assets/dc08aba6-9dcc-48df-b7c2-b082ca9dee9f" />
    <img width="270" height="280" alt="obraz" src="https://github.com/user-attachments/assets/1a4e052e-b123-4119-97ce-1619166e6769" />
    <img width="270" height="280" alt="obraz" src="https://github.com/user-attachments/assets/d5c30639-fcc5-405b-b553-183e612e3b98" />

