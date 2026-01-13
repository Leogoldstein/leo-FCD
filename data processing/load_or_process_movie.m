function [motion_energy_group, avg_motion_energy_group] = load_or_process_movie(current_gcamp_TSeries_path, gcamp_output_folders, avg_block)

    numFolders = length(current_gcamp_TSeries_path);
    camFolders = cell(numFolders, 1);
    motion_energy_group = cell(numFolders, 1);
    avg_motion_energy_group = cell(numFolders, 1);

    % chemin vers Fiji (à modifier si nécessaire)
    fijiPath = 'C:\Users\goldstein\Fiji.app\fiji-windows-x64.exe';

    for m = 1:length(numFolders)

        camPath = fullfile(current_gcamp_TSeries_path{m}, 'cam', 'Concatenated');
        cameraPath = fullfile(current_gcamp_TSeries_path{m}, 'camera', 'Concatenated');

        if isfolder(camPath)
            camFolders{m} = camPath;
            fprintf('Found cam folder: %s\n', camPath);
        elseif isfolder(cameraPath)
            camFolders{m} = cameraPath;
            fprintf('Found camera folder: %s\n', cameraPath);
        else
            fprintf('No Camera images found in %s.\n', current_gcamp_TSeries_path{m});
            continue;
        end
         
        filepath = fullfile(camFolders{m}, 'cam_crop.tif');
        disp(filepath)

        if exist(filepath, 'file') == 2
            savePath = fullfile(gcamp_output_folders{m}, 'results_movie.mat'); 
    
            if exist(savePath, 'file') == 2 
                disp(['Loading file: ', savePath]);
                data = load(savePath);
                motion_energy = data.motion_energy;
    
            else
                choice = input('Voulez-vous ouvrir le film dans Fiji pour cropper ? (1/2) ', 's');
                if strcmpi(choice, '1')
                    fprintf('Ouverture de %s dans Fiji...\n', filepath);
                    % Ouvrir Fiji avec le .tif
                    system(sprintf('"%s" "%s"', fijiPath, filepath));
                    
                    motion_energy = compute_motion_energy(filepath);
                    save(savePath, 'motion_energy');
                    
                elseif strcmpi(choice, '2')
                    subchoice = input('Voulez-vous calculer la motion_energy sur le film tel quel ou passer ? (1/2) ', 's');
                    if strcmpi(subchoice, '1')
                        motion_energy = compute_motion_energy(filepath);
                        save(savePath, 'motion_energy');
                    else
                        motion_energy = [];  % Ne pas calculer
                    end
                else
                    fprintf('Motion energy non calculée.\n');
                    motion_energy = [];
                end
            
                motion_energy_group{m} = motion_energy; 
            
                if ~isempty(motion_energy)
                    avg_motion_energy = average_frames(motion_energy, avg_block);  % ou 'trim'  
                    avg_motion_energy_group{m} = avg_motion_energy;
                else
                    avg_motion_energy_group{m} = [];
                end
            end

            motion_energy_group{m} = motion_energy; 
            if ~isempty(motion_energy)
                avg_motion_energy = average_frames(motion_energy, avg_block);  % ou 'trim'  
                avg_motion_energy_group{m} = avg_motion_energy;
            else
                avg_motion_energy_group{m} = [];
            end
        else
            fprintf('No movie found in %s.\n', camFolders{m});
            motion_energy_group{m} = [];
        end
    end
end