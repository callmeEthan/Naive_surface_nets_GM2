function auto_mesh_create()
{ 
	// Simply create a ds_list to contain shape information
	return ds_list_create();
}

function auto_mesh_add_AABB(mesh,x1,y1,z1,x2,y2,z2)
{
	// Add simple AABB box
	ds_list_add(mesh, [0, x1, y1, z1, x2, y2, z2]);
}

function auto_mesh_add_sphere(mesh, x, y, z, radius)
{
	// Add simple sphere
	ds_list_add(mesh, [1, x, y, z, abs(radius)])
}

function auto_mesh_add_noise(mesh, x1, y1, z1, x2, y2, z2)
{
	ds_list_add(mesh, [2, x1, y1, z1, x2, y2, z2]);
}

function auto_mesh_check(mesh, x, y, z)
{
	var s = ds_list_size(mesh);
	var cell = 0;
	for(var i=0;i<s;i++)
	{
		var shape = mesh[| i]
		switch(shape[0])
		{
			default:
				//if point_in_cube(x,y,z, min(shape[1], shape[4]), min(shape[2], shape[5]), min(shape[3], shape[6]), max(shape[1], shape[4]), max(shape[2], shape[5]), max(shape[3], shape[6])) cell=1
				var xmin = min(shape[1], shape[4]);
				var xmax = max(shape[1], shape[4]);
				var ymin = min(shape[2], shape[5]);
				var ymax = max(shape[2], shape[5]);
				var zmin = min(shape[3], shape[6]);
				var zmax = max(shape[3], shape[6]);
				var cx = 1-abs(x-(xmin+xmax)/2)/((xmax-xmin)/2);
				var cy = 1-abs(y-(ymin+ymax)/2)/((ymax-ymin)/2);
				var cz = 1-abs(z-(zmin+zmax)/2)/((zmax-zmin)/2);
				cell = max(cell, min(cx, cy, cz));
				break
				 
			case 1:
				cell = max(cell, 1.-point_distance_3d(x,y,z, shape[1], shape[2], shape[3])/shape[4])
				break
				
			case 2:
				var scale = 200;
				var height = 1-(z-shape[3])/(shape[6]-shape[3]);
				var value = perlin_noise(x/scale,y/scale,z/scale)*0.5+0.5
				cell = max(cell, value*power(height, 0.2))
				break
		}
	}
	return clamp(cell, 0, 1)
}

function auto_mesh_bound(mesh)
{
	var xmin=infinity, ymin=infinity, zmin=infinity;
	var xmax=-infinity, ymax=-infinity, zmax=-infinity;
	var s = ds_list_size(mesh);
	for(var i=0;i<s;i++)
	{
		var shape = mesh[| i]
		switch(shape[0])
		{
			default:
			xmin = min(xmin, shape[1], shape[4]);
			ymin = min(ymin, shape[2], shape[5]);
			zmin = min(zmin, shape[3], shape[6]);
			xmax = max(xmax, shape[1], shape[4]);
			ymax = max(ymax, shape[2], shape[5]);
			zmax = max(zmax, shape[3], shape[6]);
			break
			
			case 1:
			xmin = min(xmin, shape[1] - shape[4]);
			ymin = min(ymin, shape[2] - shape[4]);
			zmin = min(zmin, shape[3] - shape[4]);
			xmax = max(xmax, shape[1] + shape[4]);
			ymax = max(ymax, shape[2] + shape[4]);
			zmax = max(zmax, shape[3] + shape[4]);
			break
		}
	}
	return [xmin, ymin, zmin, xmax, ymax, zmax]
}

function naive_surface_nets(mesh, buffer, scale, level, iterate=1, interpolate=0.9)
{
	/* How to:
	Create a mesh list by using auto_mesh_create() first, then add shapes by using auto_mesh_add_*() commands.
	This function will generate new mesh model and smooth the shape, then write new model data into provided buffer (standard format: Position, Normal, UV, Color).
	
	Input:
		mesh: mesh data (simply a ds_list);
		buffer: Buffer to write vertex data into, should be grow type;
		scale: Size of vertex grid (not scale of shape);
		level: Isosurface level, good for using noise to generate mesh;
		iterate: How many times to smooth models, 2-3 is already good enough, 0 will return voxel shape;
		interpolate: The amount of interpolate toward 'center-of-mass';
	*/
	
	// GET BOUNDING BOX
	// Find the area containing the whole shape
	var s = ds_list_size(mesh)
	var bound = auto_mesh_bound(mesh)
	var xmin = bound[0]-scale, ymin = bound[1]-scale, zmin = bound[2]-scale;
	var xmax = bound[3]+scale, ymax = bound[4]+scale, zmax = bound[5]+scale;
	
	// CUBE MARCHING TO FIND ACTIVE VERTICES
	// Iterate through every 'cube' in the area;
	// Article: https://cerbion.net/blog/understanding-surface-nets/
	var vertices = ds_list_create();	// use ds_list to quickly iterate through active vertices;
	var adjacent = ds_map_create();		// use ds_map to quickly access vertices position data when smoothing surface net;
	var corner = array_create(8)
	for(var xx=xmin; xx<xmax; xx+=scale)
	for(var yy=ymin; yy<ymax; yy+=scale)
	for(var zz=zmin; zz<zmax; zz+=scale)
	{
		/*
			Check 8 corner of current 'cube'
			Voxel corner indices:
					Z
				
			        4          5
			        o----------o
			       /|         /|
			     7/ |       6/ |
			     o--|-------o  |
			     |  o-------|--o	X
			     | /0       | /1
			     |/         |/
			     o----------o
			     3          2
			  Y
		*/
        var bit = 0;
		corner[@0]=auto_mesh_check(mesh, xx,yy,zz)
		corner[@1]=auto_mesh_check(mesh, xx+scale,yy,zz)
		corner[@2]=auto_mesh_check(mesh, xx+scale,yy+scale,zz)
		corner[@3]=auto_mesh_check(mesh, xx,yy+scale,zz)
		corner[@4]=auto_mesh_check(mesh, xx,yy,zz+scale)
		corner[@5]=auto_mesh_check(mesh, xx+scale,yy,zz+scale)
		corner[@6]=auto_mesh_check(mesh, xx+scale,yy+scale,zz+scale)
		corner[@7]=auto_mesh_check(mesh, xx,yy+scale,zz+scale)
		if corner[0]>=level {bit |= 1}
		if corner[1]>=level {bit |= 2}
		if corner[2]>=level {bit |= 4}
		if corner[3]>=level {bit |= 8}
		if corner[4]>=level {bit |= 16}
		if corner[5]>=level {bit |= 32}
		if corner[6]>=level {bit |= 64}
		if corner[7]>=level {bit |= 128}
		// If all corner is equal, cube is either inside or outside mesh.
		//	Otherwise cube is at the iso border, add to active vertices list.
		//	Iso gradient is also used to estimate iso surface direction.
		if bit % 255 != 0
		{
			var Nx=0, Ny=0, Nz=0;
			Nx+=-corner[0];	Ny+=-corner[0];	Nz+=-corner[0]
			Nx+=corner[1];	Ny+=-corner[1]; Nz+=-corner[1]
			Nx+=corner[2];	Ny+=corner[2];	Nz+=-corner[2]
			Nx+=-corner[3];	Ny+=corner[3];	Nz+=-corner[3]
			Nx+=-corner[4];	Ny+=-corner[4];	Nz+=corner[4]
			Nx+=corner[5];	Ny+=-corner[5]; Nz+=corner[5]
			Nx+=corner[6];	Ny+=corner[6];	Nz+=corner[6]
			Nx+=-corner[7];	Ny+=corner[7];	Nz+=corner[7]
			var normal = normalize(-Nx, -Ny, -Nz)
			/*
			//		Uncomment this section to debug iso surface direction
			col = make_color_rgb(abs(normal[0])*255, abs(normal[1])*255, abs(normal[2])*255)
			buffer_add_vertex(buffer, xx+2, yy, zz, 0,0,1, 0,0, col, 1)
			buffer_add_vertex(buffer, xx-2, yy, zz, 0,0,1, 0,0, col, 1)
			buffer_add_vertex(buffer, xx+normal[0]*8, yy+normal[1]*8, zz+normal[2]*8, 0,0,1, 0,0, col, 1)
			buffer_add_vertex(buffer, xx, yy+2, zz, 0,0,1, 0,0, col, 1)
			buffer_add_vertex(buffer, xx, yy-2, zz, 0,0,1, 0,0, col, 1)
			buffer_add_vertex(buffer, xx+normal[0]*8, yy+normal[1]*8, zz+normal[2]*8, 0,0,1, 0,0, col, 1)
			buffer_add_vertex(buffer, xx, yy, zz+2, 0,0,1, 0,0, col, 1)
			buffer_add_vertex(buffer, xx, yy, zz-2, 0,0,1, 0,0, col, 1)
			buffer_add_vertex(buffer, xx+normal[0]*8, yy+normal[1]*8, zz+normal[2]*8, 0,0,1, 0,0, col, 1)
			*/
			ds_list_add(vertices, [xx, yy, zz]);
			ds_map_add(adjacent, string([xx, yy, zz]), [xx,yy,zz, normal[0], normal[1], normal[2]]);
		}
	}
	
	// SMOOTHING MESH
	// Iterate through all active vertices, check adjacent position for neighbour active vertices
	// Calculate the 'center-of-mass', then interpolate current vertices toward that center.
	// Results in smoother surface after each iteration.
	var vs = ds_list_size(vertices);
	repeat(iterate) for(var i=0;i<vs;i++)
	{
		var pos = vertices[| i], sum=0;
		var xx = pos[@0];
		var yy = pos[@1];
		var zz = pos[@2];
		
		var centerx = 0, centery = 0, centerz = 0;
		if ds_map_exists(adjacent, string([xx+scale,yy,zz]))
		{
			var adj = adjacent[? string([xx+scale,yy,zz])];
			centerx += adj[0];	centery += adj[1];	centerz += adj[2];
			sum++
		}
		if ds_map_exists(adjacent, string([xx-scale,yy,zz]))
		{
			var adj = adjacent[? string([xx-scale,yy,zz])];
			centerx += adj[0];	centery += adj[1];	centerz += adj[2];
			sum++
		}
		if ds_map_exists(adjacent, string([xx,yy+scale,zz]))
		{
			var adj = adjacent[? string([xx,yy+scale,zz])];
			centerx += adj[0];	centery += adj[1];	centerz += adj[2];
			sum++
		}
		if ds_map_exists(adjacent, string([xx,yy-scale,zz]))
		{
			var adj = adjacent[? string([xx,yy-scale,zz])];
			centerx += adj[0];	centery += adj[1];	centerz += adj[2];
			sum++
		}
		if ds_map_exists(adjacent, string([xx,yy,zz+scale]))
		{
			var adj = adjacent[? string([xx,yy,zz+scale])];
			centerx += adj[0];	centery += adj[1];	centerz += adj[2];
			sum++
		}
		if ds_map_exists(adjacent, string([xx,yy,zz-scale]))
		{
			var adj = adjacent[? string([xx,yy,zz-scale])];
			centerx += adj[0];	centery += adj[1];	centerz += adj[2];
			sum++
		}
		centerx/=sum;
		centery/=sum;
		centerz/=sum;
		
		pos = adjacent[? string([xx,yy,zz])];
		pos[@0] = lerp(pos[0], centerx, interpolate);
		pos[@1] = lerp(pos[1], centery, interpolate);
		pos[@2] = lerp(pos[2], centerz, interpolate);
	}
	
	// GENERATING MESH
	// Iterate through active vertices and generate model.
	// Only check positive x,y,z. Not to create dupplicate quad.
	//	Use iso gradient direction to determine vertex order (clockwise or otherwise), and use cross_product to caculate normal.
	var pos0, pos1, pos2, pos3, col=c_white, order;
	for(var i=0;i<vs;i++)
	{
		col = c_white
		pos = vertices[| i];
		xx = pos[@0];
		yy = pos[@1];
		zz = pos[@2];
		pos0 = adjacent[? string([xx,yy,zz])];
		
		var px = ds_map_exists(adjacent, string([xx+scale,yy,zz]))
		var py = ds_map_exists(adjacent, string([xx,yy+scale,zz]))
		var pz = ds_map_exists(adjacent, string([xx,yy,zz+scale]))
				
		// Z face
		var nx=0, ny=0, nz=0;
		var col=make_color_rgb(90,90,255);
		if px && py && ds_map_exists(adjacent, string([xx+scale,yy+scale,zz]))
		{
			var pos1 = adjacent[? string([xx,yy+scale,zz])]
			var pos2 = adjacent[? string([xx+scale,yy+scale,zz])]
			var pos3 = adjacent[? string([xx+scale,yy,zz])]
			var hand1 = [pos1[0]-pos0[0], pos1[1]-pos0[1], pos1[2]-pos0[2]]
			var hand2 = [pos3[0]-pos0[0], pos3[1]-pos0[1], pos3[2]-pos0[2]]
			var hand3 = [pos1[0]-pos2[0], pos1[1]-pos2[1], pos1[2]-pos2[2]]
			var hand4 = [pos3[0]-pos2[0], pos3[1]-pos2[1], pos3[2]-pos2[2]]
			if (pos0[@5]+pos1[@5]+pos2[@5]+pos3[@5])<0 order=true else order=false
			if order
			{
				cross_product(hand1, hand2, normal)
				buffer_add_vertex(buffer, pos0[0], pos0[1], pos0[2], normal[0],normal[1],normal[2], 0,1, col, 1)
				buffer_add_vertex(buffer, pos1[0], pos1[1], pos1[2], normal[0],normal[1],normal[2], 1,1, col, 1)
				buffer_add_vertex(buffer, pos3[0], pos3[1], pos3[2], normal[0],normal[1],normal[2], 0,0, col, 1)
				cross_product(hand4, hand3, normal)
				buffer_add_vertex(buffer, pos1[0], pos1[1], pos1[2], normal[0],normal[1],normal[2], 1,1, col, 1)
				buffer_add_vertex(buffer, pos2[0], pos2[1], pos2[2], normal[0],normal[1],normal[2], 1,0, col, 1)
				buffer_add_vertex(buffer, pos3[0], pos3[1], pos3[2], normal[0],normal[1],normal[2], 0,0, col, 1)
			} else {
				cross_product(hand2, hand1, normal)
				buffer_add_vertex(buffer, pos3[0], pos3[1], pos3[2], normal[0],normal[1],normal[2], 0,0, col, 1)
				buffer_add_vertex(buffer, pos1[0], pos1[1], pos1[2], normal[0],normal[1],normal[2], 1,1, col, 1)
				buffer_add_vertex(buffer, pos0[0], pos0[1], pos0[2], normal[0],normal[1],normal[2], 0,1, col, 1)
				cross_product(hand3, hand4, normal)
				buffer_add_vertex(buffer, pos3[0], pos3[1], pos3[2], normal[0],normal[1],normal[2], 0,0, col, 1)
				buffer_add_vertex(buffer, pos2[0], pos2[1], pos2[2], normal[0],normal[1],normal[2], 1,0, col, 1)
				buffer_add_vertex(buffer, pos1[0], pos1[1], pos1[2], normal[0],normal[1],normal[2], 1,1, col, 1)
			}
		}
		// X face
		var col=make_color_rgb(255,90,90);
		if py && pz && ds_map_exists(adjacent, string([xx,yy+scale,zz+scale]))
		{
			var pos1 = adjacent[? string([xx,yy+scale,zz])]
			var pos2 = adjacent[? string([xx,yy+scale,zz+scale])]
			var pos3 = adjacent[? string([xx,yy,zz+scale])]
			var hand1 = [pos1[0]-pos0[0], pos1[1]-pos0[1], pos1[2]-pos0[2]]
			var hand2 = [pos3[0]-pos0[0], pos3[1]-pos0[1], pos3[2]-pos0[2]]
			var hand3 = [pos1[0]-pos2[0], pos1[1]-pos2[1], pos1[2]-pos2[2]]
			var hand4 = [pos3[0]-pos2[0], pos3[1]-pos2[1], pos3[2]-pos2[2]]
			if (pos0[@3]+pos1[@3]+pos2[@3]+pos3[@3])<0 order=true else order=false
			if !order
			{
				cross_product(hand1, hand2, normal)
				buffer_add_vertex(buffer, pos0[0], pos0[1], pos0[2], normal[0],normal[1],normal[2], 0,1, col, 1)
				buffer_add_vertex(buffer, pos1[0], pos1[1], pos1[2], normal[0],normal[1],normal[2], 1,1, col, 1)
				buffer_add_vertex(buffer, pos3[0], pos3[1], pos3[2], normal[0],normal[1],normal[2], 0,0, col, 1)
				cross_product(hand4, hand3, normal)
				buffer_add_vertex(buffer, pos1[0], pos1[1], pos1[2], normal[0],normal[1],normal[2], 1,1, col, 1)
				buffer_add_vertex(buffer, pos2[0], pos2[1], pos2[2], normal[0],normal[1],normal[2], 1,0, col, 1)
				buffer_add_vertex(buffer, pos3[0], pos3[1], pos3[2], normal[0],normal[1],normal[2], 0,0, col, 1)
			} else {
				cross_product(hand2, hand1, normal)
				buffer_add_vertex(buffer, pos3[0], pos3[1], pos3[2], normal[0],normal[1],normal[2], 0,0, col, 1)
				buffer_add_vertex(buffer, pos1[0], pos1[1], pos1[2], normal[0],normal[1],normal[2], 1,1, col, 1)
				buffer_add_vertex(buffer, pos0[0], pos0[1], pos0[2], normal[0],normal[1],normal[2], 0,1, col, 1)
				cross_product(hand3, hand4, normal)
				buffer_add_vertex(buffer, pos3[0], pos3[1], pos3[2], normal[0],normal[1],normal[2], 0,0, col, 1)
				buffer_add_vertex(buffer, pos2[0], pos2[1], pos2[2], normal[0],normal[1],normal[2], 1,0, col, 1)
				buffer_add_vertex(buffer, pos1[0], pos1[1], pos1[2], normal[0],normal[1],normal[2], 1,1, col, 1)
			}
		}
		// Y face
		var col=make_color_rgb(90,255,90);
		if px && pz && ds_map_exists(adjacent, string([xx+scale,yy,zz+scale]))
		{
			var pos1 = adjacent[? string([xx+scale,yy,zz])]
			var pos2 = adjacent[? string([xx+scale,yy,zz+scale])]
			var pos3 = adjacent[? string([xx,yy,zz+scale])]
			var hand1 = [pos1[0]-pos0[0], pos1[1]-pos0[1], pos1[2]-pos0[2]]
			var hand2 = [pos3[0]-pos0[0], pos3[1]-pos0[1], pos3[2]-pos0[2]]
			var hand3 = [pos1[0]-pos2[0], pos1[1]-pos2[1], pos1[2]-pos2[2]]
			var hand4 = [pos3[0]-pos2[0], pos3[1]-pos2[1], pos3[2]-pos2[2]]
			if (pos0[@4]+pos1[@4]+pos2[@4]+pos3[@4])<0 order=true else order=false
			if order
			{
				cross_product(hand1, hand2, normal)
				buffer_add_vertex(buffer, pos0[0], pos0[1], pos0[2], normal[0],normal[1],normal[2], 0,1, col, 1)
				buffer_add_vertex(buffer, pos1[0], pos1[1], pos1[2], normal[0],normal[1],normal[2], 1,1, col, 1)
				buffer_add_vertex(buffer, pos3[0], pos3[1], pos3[2], normal[0],normal[1],normal[2], 0,0, col, 1)
				cross_product(hand4, hand3, normal)
				buffer_add_vertex(buffer, pos1[0], pos1[1], pos1[2], normal[0],normal[1],normal[2], 1,1, col, 1)
				buffer_add_vertex(buffer, pos2[0], pos2[1], pos2[2], normal[0],normal[1],normal[2], 1,0, col, 1)
				buffer_add_vertex(buffer, pos3[0], pos3[1], pos3[2], normal[0],normal[1],normal[2], 0,0, col, 1)
			} else {
				cross_product(hand2, hand1, normal)
				buffer_add_vertex(buffer, pos3[0], pos3[1], pos3[2], normal[0],normal[1],normal[2], 0,0, col, 1)
				buffer_add_vertex(buffer, pos1[0], pos1[1], pos1[2], normal[0],normal[1],normal[2], 1,1, col, 1)
				buffer_add_vertex(buffer, pos0[0], pos0[1], pos0[2], normal[0],normal[1],normal[2], 0,1, col, 1)
				cross_product(hand3, hand4, normal)
				buffer_add_vertex(buffer, pos3[0], pos3[1], pos3[2], normal[0],normal[1],normal[2], 0,0, col, 1)
				buffer_add_vertex(buffer, pos2[0], pos2[1], pos2[2], normal[0],normal[1],normal[2], 1,0, col, 1)
				buffer_add_vertex(buffer, pos1[0], pos1[1], pos1[2], normal[0],normal[1],normal[2], 1,1, col, 1)
			}
		}
	}
	ds_list_destroy(vertices);
	ds_map_destroy(adjacent);
}

function naive_surface_nets_smooth_normal(mesh, buffer, scale, level, iterate=1, interpolate=0.8)
{
	// Same function as auto_mesh_surface_nets, with added step of calculating smooth normal.
	// GET BOUNDING BOX
	// Find the area containing the whole shape
	var s = ds_list_size(mesh)
	var bound = auto_mesh_bound(mesh)
	var xmin = bound[0]-scale, ymin = bound[1]-scale, zmin = bound[2]-scale;
	var xmax = bound[3]+scale, ymax = bound[4]+scale, zmax = bound[5]+scale;
	
	// CUBE MARCHING TO FIND ACTIVE VERTICES
	var vertices = ds_list_create();
	var adjacent = ds_map_create();
	var corner = array_create(8)
	for(var xx=xmin; xx<xmax; xx+=scale)
	for(var yy=ymin; yy<ymax; yy+=scale)
	for(var zz=zmin; zz<zmax; zz+=scale)
	{
        var bit = 0;
		corner[@0]=auto_mesh_check(mesh, xx,yy,zz)
		corner[@1]=auto_mesh_check(mesh, xx+scale,yy,zz)
		corner[@2]=auto_mesh_check(mesh, xx+scale,yy+scale,zz)
		corner[@3]=auto_mesh_check(mesh, xx,yy+scale,zz)
		corner[@4]=auto_mesh_check(mesh, xx,yy,zz+scale)
		corner[@5]=auto_mesh_check(mesh, xx+scale,yy,zz+scale)
		corner[@6]=auto_mesh_check(mesh, xx+scale,yy+scale,zz+scale)
		corner[@7]=auto_mesh_check(mesh, xx,yy+scale,zz+scale)
		if corner[0]>=level {bit |= 1}
		if corner[1]>=level {bit |= 2}
		if corner[2]>=level {bit |= 4}
		if corner[3]>=level {bit |= 8}
		if corner[4]>=level {bit |= 16}
		if corner[5]>=level {bit |= 32}
		if corner[6]>=level {bit |= 64}
		if corner[7]>=level {bit |= 128}
		if bit % 255 != 0
		{
			var Nx=0, Ny=0, Nz=0;
			Nx+=-corner[0];	Ny+=-corner[0];	Nz+=-corner[0]
			Nx+=corner[1];	Ny+=-corner[1]; Nz+=-corner[1]
			Nx+=corner[2];	Ny+=corner[2];	Nz+=-corner[2]
			Nx+=-corner[3];	Ny+=corner[3];	Nz+=-corner[3]
			Nx+=-corner[4];	Ny+=-corner[4];	Nz+=corner[4]
			Nx+=corner[5];	Ny+=-corner[5]; Nz+=corner[5]
			Nx+=corner[6];	Ny+=corner[6];	Nz+=corner[6]
			Nx+=-corner[7];	Ny+=corner[7];	Nz+=corner[7]
			var normal = normalize(-Nx, -Ny, -Nz)
			ds_list_add(vertices, [xx, yy, zz]);
			ds_map_add(adjacent, string([xx, yy, zz]), [xx,yy,zz, normal[0], normal[1], normal[2], 0,0,0]);
		}
	}
	
	// SMOOTHING VERTICES
	var vs = ds_list_size(vertices);
	repeat(iterate) for(var i=0;i<vs;i++)
	{
		var pos = vertices[| i], sum=0;
		var xx = pos[@0];
		var yy = pos[@1];
		var zz = pos[@2];
		
		var centerx = 0, centery = 0, centerz = 0;
		if ds_map_exists(adjacent, string([xx+scale,yy,zz]))
		{
			var adj = adjacent[? string([xx+scale,yy,zz])];
			centerx += adj[0];	centery += adj[1];	centerz += adj[2];
			sum++
		}
		if ds_map_exists(adjacent, string([xx-scale,yy,zz]))
		{
			var adj = adjacent[? string([xx-scale,yy,zz])];
			centerx += adj[0];	centery += adj[1];	centerz += adj[2];
			sum++
		}
		if ds_map_exists(adjacent, string([xx,yy+scale,zz]))
		{
			var adj = adjacent[? string([xx,yy+scale,zz])];
			centerx += adj[0];	centery += adj[1];	centerz += adj[2];
			sum++
		}
		if ds_map_exists(adjacent, string([xx,yy-scale,zz]))
		{
			var adj = adjacent[? string([xx,yy-scale,zz])];
			centerx += adj[0];	centery += adj[1];	centerz += adj[2];
			sum++
		}
		if ds_map_exists(adjacent, string([xx,yy,zz+scale]))
		{
			var adj = adjacent[? string([xx,yy,zz+scale])];
			centerx += adj[0];	centery += adj[1];	centerz += adj[2];
			sum++
		}
		if ds_map_exists(adjacent, string([xx,yy,zz-scale]))
		{
			var adj = adjacent[? string([xx,yy,zz-scale])];
			centerx += adj[0];	centery += adj[1];	centerz += adj[2];
			sum++
		}
		centerx/=sum;
		centery/=sum;
		centerz/=sum;
		
		pos = adjacent[? string([xx,yy,zz])];
		pos[@0] = lerp(pos[0], centerx, interpolate);
		pos[@1] = lerp(pos[1], centery, interpolate);
		pos[@2] = lerp(pos[2], centerz, interpolate);
	}
	
	// CALCULATE NORMAL
	// Similarly to naive_surface_nets function, use iso gradient direction to determine vertex order, and use cross_product to calculate normal.
	//	For each vertice, find all vertex triangle connect to it, and normalize the total sum of their normal.
	var pos0, pos1, pos2, pos3, order;
	for(var i=0;i<vs;i++)
	{
		pos = vertices[| i];
		xx = pos[@0];
		yy = pos[@1];
		zz = pos[@2];
		pos0 = adjacent[? string([xx,yy,zz])];
		
		var px = ds_map_exists(adjacent, string([xx+scale,yy,zz]))
		var py = ds_map_exists(adjacent, string([xx,yy+scale,zz]))
		var pz = ds_map_exists(adjacent, string([xx,yy,zz+scale]))
				
		// Z face
		if px && py && ds_map_exists(adjacent, string([xx+scale,yy+scale,zz]))
		{
			var pos1 = adjacent[? string([xx,yy+scale,zz])]
			var pos2 = adjacent[? string([xx+scale,yy+scale,zz])]
			var pos3 = adjacent[? string([xx+scale,yy,zz])]
			var hand1 = [pos1[0]-pos0[0], pos1[1]-pos0[1], pos1[2]-pos0[2]]
			var hand2 = [pos3[0]-pos0[0], pos3[1]-pos0[1], pos3[2]-pos0[2]]
			var hand3 = [pos1[0]-pos2[0], pos1[1]-pos2[1], pos1[2]-pos2[2]]
			var hand4 = [pos3[0]-pos2[0], pos3[1]-pos2[1], pos3[2]-pos2[2]]
			if (pos0[@5]+pos1[@5]+pos2[@5]+pos3[@5])<0 order=true else order=false
			if order
			{
				cross_product(hand1, hand2, normal)
				pos0[@6]+=normal[0];	pos0[@7]+=normal[1];	pos0[@8]+=normal[2]
				pos1[@6]+=normal[0];	pos1[@7]+=normal[1];	pos1[@8]+=normal[2]
				pos3[@6]+=normal[0];	pos3[@7]+=normal[1];	pos3[@8]+=normal[2]
				cross_product(hand4, hand3, normal)
				pos1[@6]+=normal[0];	pos1[@7]+=normal[1];	pos1[@8]+=normal[2]
				pos2[@6]+=normal[0];	pos2[@7]+=normal[1];	pos2[@8]+=normal[2]
				pos3[@6]+=normal[0];	pos3[@7]+=normal[1];	pos3[@8]+=normal[2]
			} else {
				cross_product(hand2, hand1, normal)
				pos0[@6]+=normal[0];	pos0[@7]+=normal[1];	pos0[@8]+=normal[2]
				pos1[@6]+=normal[0];	pos1[@7]+=normal[1];	pos1[@8]+=normal[2]
				pos3[@6]+=normal[0];	pos3[@7]+=normal[1];	pos3[@8]+=normal[2]
				cross_product(hand3, hand4, normal)
				pos1[@6]+=normal[0];	pos1[@7]+=normal[1];	pos1[@8]+=normal[2]
				pos2[@6]+=normal[0];	pos2[@7]+=normal[1];	pos2[@8]+=normal[2]
				pos3[@6]+=normal[0];	pos3[@7]+=normal[1];	pos3[@8]+=normal[2]
			}
		}
		// X face
		if py && pz && ds_map_exists(adjacent, string([xx,yy+scale,zz+scale]))
		{
			var pos1 = adjacent[? string([xx,yy+scale,zz])]
			var pos2 = adjacent[? string([xx,yy+scale,zz+scale])]
			var pos3 = adjacent[? string([xx,yy,zz+scale])]
			var hand1 = [pos1[0]-pos0[0], pos1[1]-pos0[1], pos1[2]-pos0[2]]
			var hand2 = [pos3[0]-pos0[0], pos3[1]-pos0[1], pos3[2]-pos0[2]]
			var hand3 = [pos1[0]-pos2[0], pos1[1]-pos2[1], pos1[2]-pos2[2]]
			var hand4 = [pos3[0]-pos2[0], pos3[1]-pos2[1], pos3[2]-pos2[2]]
			if (pos0[@3]+pos1[@3]+pos2[@3]+pos3[@3])<0 order=true else order=false
			if !order
			{
				cross_product(hand1, hand2, normal)
				pos0[@6]+=normal[0];	pos0[@7]+=normal[1];	pos0[@8]+=normal[2]
				pos1[@6]+=normal[0];	pos1[@7]+=normal[1];	pos1[@8]+=normal[2]
				pos3[@6]+=normal[0];	pos3[@7]+=normal[1];	pos3[@8]+=normal[2]
				cross_product(hand4, hand3, normal)
				pos1[@6]+=normal[0];	pos1[@7]+=normal[1];	pos1[@8]+=normal[2]
				pos2[@6]+=normal[0];	pos2[@7]+=normal[1];	pos2[@8]+=normal[2]
				pos3[@6]+=normal[0];	pos3[@7]+=normal[1];	pos3[@8]+=normal[2]
			} else {
				cross_product(hand2, hand1, normal)
				pos0[@6]+=normal[0];	pos0[@7]+=normal[1];	pos0[@8]+=normal[2]
				pos1[@6]+=normal[0];	pos1[@7]+=normal[1];	pos1[@8]+=normal[2]
				pos3[@6]+=normal[0];	pos3[@7]+=normal[1];	pos3[@8]+=normal[2]
				cross_product(hand3, hand4, normal)
				pos1[@6]+=normal[0];	pos1[@7]+=normal[1];	pos1[@8]+=normal[2]
				pos2[@6]+=normal[0];	pos2[@7]+=normal[1];	pos2[@8]+=normal[2]
				pos3[@6]+=normal[0];	pos3[@7]+=normal[1];	pos3[@8]+=normal[2]
			}
		}
		// Y face
		if px && pz && ds_map_exists(adjacent, string([xx+scale,yy,zz+scale]))
		{
			var pos1 = adjacent[? string([xx+scale,yy,zz])]
			var pos2 = adjacent[? string([xx+scale,yy,zz+scale])]
			var pos3 = adjacent[? string([xx,yy,zz+scale])]
			var hand1 = [pos1[0]-pos0[0], pos1[1]-pos0[1], pos1[2]-pos0[2]]
			var hand2 = [pos3[0]-pos0[0], pos3[1]-pos0[1], pos3[2]-pos0[2]]
			var hand3 = [pos1[0]-pos2[0], pos1[1]-pos2[1], pos1[2]-pos2[2]]
			var hand4 = [pos3[0]-pos2[0], pos3[1]-pos2[1], pos3[2]-pos2[2]]
			if (pos0[@4]+pos1[@4]+pos2[@4]+pos3[@4])<0 order=true else order=false
			if order
			{
				cross_product(hand1, hand2, normal)
				pos0[@6]+=normal[0];	pos0[@7]+=normal[1];	pos0[@8]+=normal[2]
				pos1[@6]+=normal[0];	pos1[@7]+=normal[1];	pos1[@8]+=normal[2]
				pos3[@6]+=normal[0];	pos3[@7]+=normal[1];	pos3[@8]+=normal[2]
				cross_product(hand4, hand3, normal)
				pos1[@6]+=normal[0];	pos1[@7]+=normal[1];	pos1[@8]+=normal[2]
				pos2[@6]+=normal[0];	pos2[@7]+=normal[1];	pos2[@8]+=normal[2]
				pos3[@6]+=normal[0];	pos3[@7]+=normal[1];	pos3[@8]+=normal[2]
			} else {
				cross_product(hand2, hand1, normal)
				pos0[@6]+=normal[0];	pos0[@7]+=normal[1];	pos0[@8]+=normal[2]
				pos1[@6]+=normal[0];	pos1[@7]+=normal[1];	pos1[@8]+=normal[2]
				pos3[@6]+=normal[0];	pos3[@7]+=normal[1];	pos3[@8]+=normal[2]
				cross_product(hand3, hand4, normal)
				pos1[@6]+=normal[0];	pos1[@7]+=normal[1];	pos1[@8]+=normal[2]
				pos2[@6]+=normal[0];	pos2[@7]+=normal[1];	pos2[@8]+=normal[2]
				pos3[@6]+=normal[0];	pos3[@7]+=normal[1];	pos3[@8]+=normal[2]
			}
		}
	}
	for(var i=0;i<vs;i++)
	{
		pos = vertices[| i];
		pos0 = adjacent[? string([xx,yy,zz])];
		var normal = normalize(pos0[6], pos0[7], pos0[8])
		pos0[@6]=normal[0]
		pos0[@7]=normal[1]
		pos0[@8]=normal[2]
	}
	
	// GENERATING MESH
	var pos0, pos1, pos2, pos3, col=c_white, order;
	for(var i=0;i<vs;i++)
	{
		col = c_white
		pos = vertices[| i];
		xx = pos[@0];
		yy = pos[@1];
		zz = pos[@2];
		pos0 = adjacent[? string([xx,yy,zz])];
		
		var px = ds_map_exists(adjacent, string([xx+scale,yy,zz]))
		var py = ds_map_exists(adjacent, string([xx,yy+scale,zz]))
		var pz = ds_map_exists(adjacent, string([xx,yy,zz+scale]))
				
		// Z face
		var nx=0, ny=0, nz=0;
		var col=make_color_rgb(90,90,255);
		if px && py && ds_map_exists(adjacent, string([xx+scale,yy+scale,zz]))
		{
			var pos1 = adjacent[? string([xx,yy+scale,zz])]
			var pos2 = adjacent[? string([xx+scale,yy+scale,zz])]
			var pos3 = adjacent[? string([xx+scale,yy,zz])]
			if (pos0[@5]+pos1[@5]+pos2[@5]+pos3[@5])<0 order=true else order=false
			if order
			{
				buffer_add_vertex(buffer, pos0[0], pos0[1], pos0[2], pos0[6], pos0[7], pos0[8], 0,1, col, 1)
				buffer_add_vertex(buffer, pos1[0], pos1[1], pos1[2], pos1[6], pos1[7], pos1[8], 1,1, col, 1)
				buffer_add_vertex(buffer, pos3[0], pos3[1], pos3[2], pos3[6], pos3[7], pos3[8], 0,0, col, 1)
				buffer_add_vertex(buffer, pos1[0], pos1[1], pos1[2], pos1[6], pos1[7], pos1[8], 1,1, col, 1)
				buffer_add_vertex(buffer, pos2[0], pos2[1], pos2[2], pos2[6], pos2[7], pos2[8], 1,0, col, 1)
				buffer_add_vertex(buffer, pos3[0], pos3[1], pos3[2], pos3[6], pos3[7], pos3[8], 0,0, col, 1)
			} else {
				buffer_add_vertex(buffer, pos3[0], pos3[1], pos3[2], pos3[6], pos3[7], pos3[8], 0,0, col, 1)
				buffer_add_vertex(buffer, pos1[0], pos1[1], pos1[2], pos1[6], pos1[7], pos1[8], 1,1, col, 1)
				buffer_add_vertex(buffer, pos0[0], pos0[1], pos0[2], pos0[6], pos0[7], pos0[8], 0,1, col, 1)
				buffer_add_vertex(buffer, pos3[0], pos3[1], pos3[2], pos3[6], pos3[7], pos3[8], 0,0, col, 1)
				buffer_add_vertex(buffer, pos2[0], pos2[1], pos2[2], pos2[6], pos2[7], pos2[8], 1,0, col, 1)
				buffer_add_vertex(buffer, pos1[0], pos1[1], pos1[2], pos1[6], pos1[7], pos1[8], 1,1, col, 1)
			}
		}
		// X face
		var col=make_color_rgb(255,90,90);
		if py && pz && ds_map_exists(adjacent, string([xx,yy+scale,zz+scale]))
		{
			var pos1 = adjacent[? string([xx,yy+scale,zz])]
			var pos2 = adjacent[? string([xx,yy+scale,zz+scale])]
			var pos3 = adjacent[? string([xx,yy,zz+scale])]
			if (pos0[@3]+pos1[@3]+pos2[@3]+pos3[@3])<0 order=true else order=false
			if !order
			{
				buffer_add_vertex(buffer, pos0[0], pos0[1], pos0[2], pos0[6], pos0[7], pos0[8], 0,1, col, 1)
				buffer_add_vertex(buffer, pos1[0], pos1[1], pos1[2], pos1[6], pos1[7], pos1[8], 1,1, col, 1)
				buffer_add_vertex(buffer, pos3[0], pos3[1], pos3[2], pos3[6], pos3[7], pos3[8], 0,0, col, 1)
				buffer_add_vertex(buffer, pos1[0], pos1[1], pos1[2], pos1[6], pos1[7], pos1[8], 1,1, col, 1)
				buffer_add_vertex(buffer, pos2[0], pos2[1], pos2[2], pos2[6], pos2[7], pos2[8], 1,0, col, 1)
				buffer_add_vertex(buffer, pos3[0], pos3[1], pos3[2], pos3[6], pos3[7], pos3[8], 0,0, col, 1)
			} else {
				buffer_add_vertex(buffer, pos3[0], pos3[1], pos3[2], pos3[6], pos3[7], pos3[8], 0,0, col, 1)
				buffer_add_vertex(buffer, pos1[0], pos1[1], pos1[2], pos1[6], pos1[7], pos1[8], 1,1, col, 1)
				buffer_add_vertex(buffer, pos0[0], pos0[1], pos0[2], pos0[6], pos0[7], pos0[8], 0,1, col, 1)
				buffer_add_vertex(buffer, pos3[0], pos3[1], pos3[2], pos3[6], pos3[7], pos3[8], 0,0, col, 1)
				buffer_add_vertex(buffer, pos2[0], pos2[1], pos2[2], pos2[6], pos2[7], pos2[8], 1,0, col, 1)
				buffer_add_vertex(buffer, pos1[0], pos1[1], pos1[2], pos1[6], pos1[7], pos1[8], 1,1, col, 1)
			}
		}
		// Y face
		var col=make_color_rgb(90,255,90);
		if px && pz && ds_map_exists(adjacent, string([xx+scale,yy,zz+scale]))
		{
			var pos1 = adjacent[? string([xx+scale,yy,zz])]
			var pos2 = adjacent[? string([xx+scale,yy,zz+scale])]
			var pos3 = adjacent[? string([xx,yy,zz+scale])]
			if (pos0[@4]+pos1[@4]+pos2[@4]+pos3[@4])<0 order=true else order=false
			if order
			{
				buffer_add_vertex(buffer, pos0[0], pos0[1], pos0[2], pos0[6], pos0[7], pos0[8], 0,1, col, 1)
				buffer_add_vertex(buffer, pos1[0], pos1[1], pos1[2], pos1[6], pos1[7], pos1[8], 1,1, col, 1)
				buffer_add_vertex(buffer, pos3[0], pos3[1], pos3[2], pos3[6], pos3[7], pos3[8], 0,0, col, 1)
				buffer_add_vertex(buffer, pos1[0], pos1[1], pos1[2], pos1[6], pos1[7], pos1[8], 1,1, col, 1)
				buffer_add_vertex(buffer, pos2[0], pos2[1], pos2[2], pos2[6], pos2[7], pos2[8], 1,0, col, 1)
				buffer_add_vertex(buffer, pos3[0], pos3[1], pos3[2], pos3[6], pos3[7], pos3[8], 0,0, col, 1)
			} else {
				buffer_add_vertex(buffer, pos3[0], pos3[1], pos3[2], pos3[6], pos3[7], pos3[8], 0,0, col, 1)
				buffer_add_vertex(buffer, pos1[0], pos1[1], pos1[2], pos1[6], pos1[7], pos1[8], 1,1, col, 1)
				buffer_add_vertex(buffer, pos0[0], pos0[1], pos0[2], pos0[6], pos0[7], pos0[8], 0,1, col, 1)
				buffer_add_vertex(buffer, pos3[0], pos3[1], pos3[2], pos3[6], pos3[7], pos3[8], 0,0, col, 1)
				buffer_add_vertex(buffer, pos2[0], pos2[1], pos2[2], pos2[6], pos2[7], pos2[8], 1,0, col, 1)
				buffer_add_vertex(buffer, pos1[0], pos1[1], pos1[2], pos1[6], pos1[7], pos1[8], 1,1, col, 1)
			}
		}
	}
	ds_list_destroy(vertices);
	ds_map_destroy(adjacent);
}
