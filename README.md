Replicator
==========

![Replicator](/../doc/screens/replicator.png?raw=true)

The replicator is a device similar to the Autocrafter from [Pipeworks](http://vanessae.github.io/pipeworks/). (Actually, its code is based on it.)

Just as the Autocrafter, the Replicator will use the world's recipes to automatically craft items. However, while the Autocrafter needs to be told the exact recipe, the Replicator just has to know what you want it to craft. It will then try all existing recipes to build the requested item.

Usage
-----

Right clicking a Replicator brings up a menu:

![Menu](/../doc/screens/menu.png?raw=true)

The slots in the top left of the form are your task definition: The items you put here will be replicated. 

The slots in the top right of the form are the craft results. Items that have been crafted can be found here. These can also be retrieved from the device using Filters/Injectors (from Pipeworks).

The slots in the middle of the form are the Replicator's inventory, storing the input materials. Items here are used to craft when the device operates. New items can be added here using tube-related devices (from Pipeworks). 

The slots at the bottom of the form are the player's inventory.

When sufficient materials are present in the Replicators's inventory to craft at least one of the devices in the task definition (using any recipe), the device automatically starts crafting them until it runs out of materials.

If there is more than one recipe to build an item, the Replicator will take the first one for which sufficient materials are present. If a recipe contains item groups, the first item from the invetory of that group will be taken.

Why not just use the autocrafter?
---------------------------------

The Replicators main advantage over the Autocrafter is the fact that you don't have to worry about the way your item is crafted. 

Let's say, you want to craft sticks from wood or junglewood. To craft your sticks with Autocrafters, you would need two Autocrafters, one for the wood recipe and one for the junglewood recipe, and probably some sorting tubes etc. Crafting yours sticks with Replicators is much easier: You need only one Replicator, tell it that you want sticks and supply it with any kind of wood. 

![Pipeworks](/../doc/screens/pipeworks.png?raw=true)
