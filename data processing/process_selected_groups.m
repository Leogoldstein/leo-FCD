function selected_groups = process_selected_groups(selected_groups, metadata_results, include_blue_cells)

    for k = 1:length(selected_groups)
        gcamp_root_folders = selected_groups(k).gcamp_root_folders;
        gcamp_output_folders = selected_groups(k).gcamp_output_folders;
        current_animal_group   = selected_groups(k).animal_group;     
        current_ages_group     = selected_groups(k).ages;
        current_suite2p_group = selected_groups(k).suite2p_path;
        current_TSeries_group = selected_groups(k).TSeries_path;
        current_xml_group = selected_groups(k).xml_path;
        date_group_paths = selected_groups(k).date_group_path;
    
        meta_tbl = metadata_results{k};
        data = selected_groups(k).data;
    
        [sampling_rate_group, ~] = fill_sampling_and_sync_frames( ...
            gcamp_root_folders, current_xml_group, meta_tbl, 0.2);
    
        %===================%
        %   Mean images
        %===================%
        meanImgs_gcamp = save_mean_images( ...
            'GCaMP', current_animal_group, current_ages_group, ...
            gcamp_output_folders, current_suite2p_group(:, 1));
    
        meanImgs_blue = save_mean_images( ...
            'Electroporated', current_animal_group, current_ages_group, ...
            gcamp_output_folders, current_suite2p_group(:, 3));
    
    
        %===================%
        %   Motion energy
        %===================%
        avg_block = 5;        
        movie = load_or_process_movie( ...
            current_TSeries_group(:, 1), ...
            gcamp_output_folders, ...
            avg_block, ...
            sampling_rate_group, ...
            current_animal_group, ...
            data);
    
        data.movie = movie;
    
        %===================%
        %   GCaMP cells
        %===================%
        gcamp_plane = process_gcamp_cells( ...
            gcamp_output_folders, ...
            current_suite2p_group(:, 1), ...
            meanImgs_gcamp, ...
            data);
    
        data.gcamp_plane = gcamp_plane;
    
        %===================%
        %   blue cells
        %===================%
    
        blue_plane = process_blue_cells( ...
            gcamp_output_folders, include_blue_cells, ...
            date_group_paths, current_TSeries_group(:, 3), ...
            current_suite2p_group(:, 1), current_suite2p_group(:, 2), ...
            current_suite2p_group(:, 3), current_suite2p_group(:, 4), ...
            meanImgs_gcamp, ...
            data);
    
        data.blue_plane = blue_plane;
    
        %===================%
        %   Combined GCaMP + blue
        %===================%
        combined_plane = combined_gcamp_blue_cells(gcamp_output_folders, data);
        
        data.combined_plane = combined_plane;

        selected_groups(k).data = data;
    end
end