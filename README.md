# Naive surface nets for GameMaker2
![](https://github.com/callmeEthan/Naive_surface_nets_GM2/blob/main/screenshot/Untitled.png?raw=true)
For more detail about surface nets, please refer to [articles](https://cerbion.net/blog/understanding-surface-nets/ "articles") about this subject.  
This is meant for 3D project, assume you already worked out how to render 3D models.  
As provided, these function will generate model buffer with standard format:
```
vertex_format_begin();
vertex_format_add_position_3d();
vertex_format_add_normal();
vertex_format_add_texcoord();
vertex_format_add_colour();
global.stdFormat = vertex_format_end();
```
Some commands is also required for this function to work, such as normalize, cross_product,... You can check them inside [Requisitive_function](https://github.com/callmeEthan/Naive_surface_nets_GM2/blob/main/scripts/Requisitive_function/Requisitive_function.gml "Requisitive_function") script (they might already included in your project).
## How to use
Import the script directly into your project.  
**auto\_mesh** functions are included as simple example on how to use this function. You should create your own function to fit your use case.  
- First, use **auto\_mesh\_create()** to create a list to contain shapes information.
- Then, use **auto\_mesh\_add**_ to add shapes into this list.
- Finally supply the shape list and a buffer into the function **naive\_surface\_nets** to generate mesh.
```
buffer = buffer_create(64, buffer_grow, 1)
mesh = auto_mesh_create();
auto_mesh_add_AABB(mesh,10,100,10,300,200,200)
auto_mesh_add_sphere(mesh, 150, 150, 300, 130)
naive_surface_nets(mesh, buffer, 32, 0.5, 3);
```
Create vertex buffer and render
```
vertex_buff = vertex_create_buffer_from_buffer(buffer, global.stdFormat)
vertex_submit(vertex_buff, pr_trianglelist, -1);
```
### Draw back
- This script use iso gradient to estimate surface direction, which can be inaccurate near sharp corners.
- The process can be very slow and intense on CPU, real time generation is not possible.
- If the shape is too small it can create extra, unnecessary vertexs inside the shape, invisible from outside.
- Due to the nature of this method, the final mesh will become 'shrinked', user should take this into account.
- I'm not very good at this.
## Screenshot
#### Box shape
```
auto_mesh_add_AABB(mesh_test,10,100,10,300,300,300)
```
![](https://github.com/callmeEthan/Naive_surface_nets_GM2/blob/main/screenshot/box_strip.png?raw=true)
#### Sphere shape
```
auto_mesh_add_sphere(mesh_test, 300, 150, 150, 120)
```
![](https://github.com/callmeEthan/Naive_surface_nets_GM2/blob/main/screenshot/sphere_strip.png?raw=true)
#### Perlin noise
```
auto_mesh_add_noise(mesh_test,0,0,0,2048,2048,600);
```
![](https://github.com/callmeEthan/Naive_surface_nets_GM2/blob/main/screenshot/noise_strip.png?raw=true)

with **naive\_surface\_nets\_smooth\_normal** function
![](https://github.com/callmeEthan/Naive_surface_nets_GM2/blob/main/screenshot/noise_normalstrip.png?raw=true)
