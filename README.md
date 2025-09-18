# Scatter2D

> ### Place anything you want in your scenes, in a procedural, non-destructive way.

![Alt text](https://raw.githubusercontent.com/alex9978/scatter2d/refs/heads/v4/files/images/1.jpg)

## What is it?

This is an add-on for Godot 4, which automates the positioning of assets in a scene. If you have a lot of props to place, and you would rather not do it by hand, Scatter2D may be useful to you.


## How does it work?

The basic setup is as follows:

+ A `Scatter2D` node holds the `positionning rules` that can be edited in the inspector. This panel is very similar to Blender's modifier stack panel. Some modifiers create points, others change their transforms. You mix different modifiers in order to obtain the result you need.
+ One or more `ScatterItem` nodes to select which asset you want to place.
+ One or more `ScatterShape` items to define the area where the scattering happens.


## License

- This add-on is published under the MIT license.
