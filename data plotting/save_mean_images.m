function meanImgs = save_mean_images(current_animal_group, current_dates_group, current_ages_group, gcamp_output_folders, current_gcamp_folders_group)
    % SAVE_MEAN_IMAGES
    % Génère et sauvegarde une meanImg par plan, et retourne une structure
    % meanImgs{m}{p} où p = numéro du plan.
    
    numFolders = length(current_gcamp_folders_group);
    meanImgs = cell(1, numFolders);  % meanImgs{m}{p}

    for m = 1:numFolders

        % ---- Récupérer tous les Fall.mat = 1 par plan ----
        fall_paths = current_gcamp_folders_group{m};  % cell array de Fall.mat

        if ischar(fall_paths) || isstring(fall_paths)
            fall_paths = {char(fall_paths)};
        end

        nPlanes = numel(fall_paths);
        meanImgs{m} = cell(1, nPlanes);

        fprintf("Computing meanImgs for %d planes in folder %d\n", nPlanes, m);

        % --- charger chaque meanImg par plan ---
        for p = 1:nPlanes

            % Exemple : fall_path = ...\suite2p\plane2\Fall.mat
            fall_path = fall_paths{p};
            plane_dir = fileparts(fall_path);   % ...\suite2p\planeX

            % Chercher ops.npy ou ops.mat dans ce plan
            ops_npy = fullfile(plane_dir, 'ops.npy');
            ops_mat = fullfile(plane_dir, 'ops.mat');

            % --- Cas .npy ---
            if exist(ops_npy, 'file')
                try
                    mod = py.importlib.import_module('python_function');
                    ops = mod.read_npy_file(ops_npy);
                    meanImg = double(ops{'meanImg'});
                catch ME
                    warning("Error reading %s : %s", ops_npy, ME.message);
                    continue;
                end

            % --- Cas .mat ---
            elseif exist(ops_mat, 'file')
                data_ops = load(ops_mat);
                meanImg = data_ops.ops.meanImg;

            else
                warning("No ops.npy or ops.mat found in %s", plane_dir);
                continue;
            end

            % Stocker dans la structure
            meanImgs{m}{p} = meanImg;

            % ---- Sauvegarde image PNG ----
            png_filename = fullfile(gcamp_output_folders{m}, ...
                sprintf('Mean_image_of_%s_%s_plane%d.png', ...
                strrep(current_animal_group,' ','_'), ...
                strrep(current_ages_group{m},' ','_'), p));

            if ~isfile(png_filename)
                figure('Visible','off');
                imagesc(meanImg); colormap gray; axis off;
                title(sprintf('Mean Image – %s – %s – plane %d', ...
                    current_animal_group, current_dates_group{m}, p));
                saveas(gcf, png_filename);
                close(gcf);

                fprintf('Saved %s\n', png_filename);
            end

        end % fin boucle plan


        % --- OPTIONNEL : image moyenne sur tous les plans ---
        try
            mean_all = mean(cat(3, meanImgs{m}{:}), 3);

            png_global = fullfile(gcamp_output_folders{m}, ...
                sprintf('Mean_image_of_%s_%s.png', ...
                strrep(current_animal_group,' ','_'), ...
                strrep(current_ages_group{m},' ','_')));

            if ~isfile(png_global)
                figure('Visible','off');
                imagesc(mean_all); colormap gray; axis off;
                title(sprintf('Mean Image (all planes) – %s – %s', ...
                    current_animal_group, current_dates_group{m}));
                saveas(gcf, png_global);
                close(gcf);
            end
        catch
            warning("Unable to compute combined mean image for folder %d", m);
        end

    end % fin boucle folder
end
