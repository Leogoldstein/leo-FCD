function dataFolders_by_group = select_data_folders_by_group(choices, group_order)

    %===================%
    %   Chemins racines
    %===================%
    jm_folder   = '\\10.51.106.233\jm';
    fcd_folder  = 'D:\Imaging\FCD';
    ctrl_folder = 'D:\Imaging\WT';
    sham_folder = 'D:\Imaging\SHAM';

    nGroups = numel(choices);
    dataFolders_by_group = cell(nGroups,1);

    for i = 1:nGroups

        choice = choices(i);

        switch choice
            case 1
                current_type = 'jm';
                root_folder = jm_folder;

            case 2
                current_type = 'FCD';
                root_folder = fcd_folder;

            case 3
                current_type = 'WT';
                root_folder = ctrl_folder;

            case 4
                current_type = 'SHAM';
                root_folder = sham_folder;

            otherwise
                error('Choix invalide');
        end

        fprintf('[SELECT] %s -> %s\n', current_type, root_folder);

        dataFolders = select_folders(root_folder);

        switch choice
            case 2
                dataFolders = organize_data_by_animal(dataFolders, group_order{2});

            case 3
                dataFolders = organize_data_by_animal(dataFolders, group_order{3});

            case 4
                dataFolders = organize_data_by_animal(dataFolders, group_order{4});
        end

        dataFolders_by_group{i} = dataFolders;
    end
end