# Scatter2D

> ### Place anything you want in your 2D scenes, in a procedural, non-destructive way.

![Alt text](https://raw.githubusercontent.com/alex9978/scatter2d/refs/heads/v4/files/images/1.jpg)

## What is it?

This is an add-on for Godot 4, based on the excellent plugin [HungryProton/scatter](https://github.com/HungryProton/scatter), which automates the positioning of assets in a 2D scene. If you have a lot of props to place, and you would rather not do it by hand, Scatter2D may be useful to you.


## How does it work?

The basic setup is as follows:

+ A `Scatter2D` node holds the `positioning rules` that can be edited in the inspector. This panel is very similar to Blender's modifier stack panel. Some modifiers create points, others change their transforms. You mix different modifiers in order to obtain the result you need.
+ One or more `ScatterItem` nodes to select which asset you want to place.
+ One or more `ScatterShape` items to define the area where the scattering happens.


### Creating points

| ![grid](https://raw.githubusercontent.com/alex9978/scatter2d/refs/heads/v4/files/images/grid.png) | ![random](https://raw.githubusercontent.com/alex9978/scatter2d/refs/heads/v4/files/images/random.png) |
|---------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------|
| Placing items aligned on a grid                                                                   | Placing items randomly                                                                                |
|![poisson](https://raw.githubusercontent.com/alex9978/scatter2d/refs/heads/v4/files/images/poisson.png) | ![along_edge](https://raw.githubusercontent.com/alex9978/scatter2d/refs/heads/v4/files/images/edges.png) |
| Placing items with poisson                                                                             | Placing items along an edge                                                                              |


### Defining the domain

Scatter currently ships with five shape types: Box, Circle, Path, Polygon and TileMapLayer. They can be combined to create more complex shapes. If a shape has an inverted color (light blue in the example), it is a negative shape, where no items must be placed.

| ![domain](https://raw.githubusercontent.com/alex9978/scatter2d/refs/heads/v4/files/images/domain.png) |
|-------------------------------------------------------------------------------------------------------|


## License

- This add-on is published under the MIT license.
