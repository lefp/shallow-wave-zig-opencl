kernel void render(write_only image2d_t render_target) {
    int pixel_xcoord = get_global_id(0);
    int pixel_ycoord = get_global_id(1);

    int width  = get_image_width(render_target);
    int height = get_image_height(render_target);

    float brightness = (float)pixel_xcoord / (float)width;
    float4 color = brightness * (float4)(0.f, 0.f, 1.f, 1.f);
    
    write_imagef(render_target, (int2)(pixel_xcoord, pixel_ycoord), color);
}
