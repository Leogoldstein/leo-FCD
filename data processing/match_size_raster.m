function [all_isort1, all_MAct, all_prop_MAct] = match_size_raster(all_isort1, all_DF, all_ops, all_Raster, synchronous_frames, all_MAct, all_prop_MAct)
    % Fonction pour déterminer le nombre minimal de cellules à tracer, stocker ce nombre,
    % et sélectionner aléatoirement ce nombre de cellules à partir des tableaux isort1 tout en préservant l'ordre.
    % Met à jour le tableau all_isort1 pour inclure uniquement les cellules sélectionnées.
    % Enregistre les matrices DF appariées et les renvoie en sortie.
    
    % Déterminer le nombre de paires
    num_pairs = size(all_DF, 1); 
    disp(num_pairs)

    % Traiter chaque paire
    for pair_idx = 1:num_pairs
        try

            % Extraction des données isort1 pour les deux ensembles de données
            isort1_1 = all_isort1{pair_idx, 1}{1, 1};
            isort1_2 = all_isort1{pair_idx, 1}{2, 1};
            
	    ops1 = all_ops{pair_idx, 1}{1, 1};
	    ops2 = all_ops{pair_idx, 1}{2, 1};

            DF1 = all_DF{pair_idx, 1}{1, 1};
            [num_cells_1, numFrames1] = size(DF1);
         
            DF2 = all_DF{pair_idx, 1}{2, 1};
            [num_cells_2, numFrames2] = size(DF2);

            Raster1 = all_Raster{pair_idx,1}{1,1};
            Raster2 = all_Raster{pair_idx,1}{2,1};

            % Find the minimal number of cells between the two datasets
            num_cells_to_plot = min(num_cells_1, num_cells_2);

             % Randomly select num_cells_to_plot cells from the smaller dataset
            if num_cells_1 > num_cells_2
                % Select random indices from isort1_1 to match isort1_2
                selected_indices_1 = randperm(num_cells_1, num_cells_to_plot);
                selected_isort1_1 = isort1_1(selected_indices_1);
		
		% Try processing the raster plots, handle errors if they occur
  	        try
                   [selected_isort1_1, ~, ~] = processRasterPlots(DF1(isort1_1_filtered, :), ops1);
                catch ME
            	   % If there's an error, display a warning and skip to the next dataset
                   warning(['Error processing raster plots for workingfolder ' num2str(k) ': ' ME.message]);
                   continue;  % Skip to the next iteration
                end
			
                all_isort1{pair_idx, 1}{1, 1} = selected_isort1_1;
           
                MAct1 = zeros(1, numFrames1 - synchronous_frames);
                for i = 1:(numFrames1 - synchronous_frames)
                    MAct1(i) = sum(max(Raster1(selected_indices_1, i:i+synchronous_frames), [], 2));
                end

                all_MAct{pair_idx,1}{1,1} = MAct1;
                all_prop_MAct{pair_idx,1}{1,1} = MAct1 / num_cells_to_plot;

            else
                % Select random indices from isort1_2 to match isort1_1
                selected_indices_2 = randperm(num_cells_2, num_cells_to_plot);
                selected_isort1_2 = isort1_2(selected_indices_2);
		
		% Try processing the raster plots, handle errors if they occur
  	        try
                   [selected_isort1_2, ~, ~] = processRasterPlots(DF2(isort1_2_filtered, :), ops2);
                catch ME
            	   % If there's an error, display a warning and skip to the next dataset
                   warning(['Error processing raster plots for workingfolder ' num2str(k) ': ' ME.message]);
                   continue;  % Skip to the next iteration
                end

                all_isort1{pair_idx, 1}{2, 1} = selected_isort1_2;
           
                MAct2 = zeros(1, numFrames2 - synchronous_frames);
                for i = 1:(numFrames2 - synchronous_frames)
                    MAct2(i) = sum(max(Raster2(selected_indices_2, i:i+synchronous_frames), [], 2));
                end

                all_MAct{pair_idx,1}{2,1} = MAct2;
                all_prop_MAct{pair_idx,1}{2,1} = MAct2 / num_cells_to_plot;
            end

        catch ME
            warning('Error processing pair %d: %s', pair_idx, ME.message);
        end
    end
end


            

            