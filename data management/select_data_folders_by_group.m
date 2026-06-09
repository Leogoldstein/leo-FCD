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

    %===================%
    %   Charger animal_date_list depuis le workspace
    %===================%
    animal_date_list = {};
    if evalin('base', 'exist(''animal_date_list'', ''var'')')
        animal_date_list = evalin('base', 'animal_date_list');
    end

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

        %======================================================
        % FCD : proposer mtor / animal / date seulement si animal_date_list existe
        %======================================================
        if choice == 2
        
            has_animal_date_list = ~isempty(animal_date_list);
        
            rows = [];
            if has_animal_date_list
                type_col = animal_date_list(:,1);
                rows = find(strcmpi(type_col, current_type));
            end
        
            if has_animal_date_list && ~isempty(rows)
        
                level_choice = questdlg( ...
                    'Select FCD folders by:', ...
                    'Selection level', ...
                    'mtor', 'animal', 'date', 'mtor');
        
                if isempty(level_choice)
                    dataFolders_by_group{i} = {};
                    continue;
                end
        
            else
                level_choice = 'manual';
            end
        
            start_folder = root_folder;
        
            if strcmp(level_choice, 'mtor')
        
                start_folder = root_folder;
        
            elseif strcmp(level_choice, 'animal')
        
                group_col  = animal_date_list(rows,2);
                animal_col = animal_date_list(rows,3);
        
                for k = 1:numel(group_col)
                    if isempty(group_col{k})
                        group_col{k} = animal_col{k};
                    end
                end
        
                unique_groups = unique(group_col);
        
                if isscalar(unique_groups)
                    start_folder = fullfile(root_folder, unique_groups{1});
                end
        
            elseif strcmp(level_choice, 'date')
        
                group_col  = animal_date_list(rows,2);
                animal_col = animal_date_list(rows,3);
        
                for k = 1:numel(group_col)
                    if isempty(group_col{k})
                        group_col{k} = animal_col{k};
                    end
                end
        
                unique_groups  = unique(group_col);
                unique_animals = unique(animal_col);
        
                if isscalar(unique_groups) && isscalar(unique_animals)
                    start_folder = fullfile(root_folder, unique_groups{1}, unique_animals{1});
                elseif isscalar(unique_groups)
                    start_folder = fullfile(root_folder, unique_groups{1});
                end
            end
        
            fprintf('[SELECT] FCD %s -> %s\n', level_choice, start_folder);
            dataFolders = select_folders(start_folder);
            dataFolders = organize_data_by_animal(dataFolders, group_order{2});

        %======================================================
        % Non-FCD : pas de proposition de niveau
        %======================================================
        else
            fprintf('[SELECT] %s -> %s\n', current_type, root_folder);
            dataFolders = select_folders(root_folder);

            switch choice
                case 3
                    dataFolders = organize_data_by_animal(dataFolders, group_order{3});
                case 4
                    dataFolders = organize_data_by_animal(dataFolders, group_order{4});
            end
        end

        dataFolders_by_group{i} = dataFolders;
    end
end