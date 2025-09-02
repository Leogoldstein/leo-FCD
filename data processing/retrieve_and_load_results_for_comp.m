function [directories, all_DF, all_ops, all_isort1, all_Raster, all_MAct, all_prop_MAct, animal_date_list] = retrieve_and_load_results_for_comp(PathSave)
    % Check if the provided path is valid
    if ~isfolder(PathSave)
        error('Le chemin spécifié n''est pas valide.');
    end
    
    % Select all subfolders in the given path
    selectedFolders = dir(PathSave);
    selectedFolders = selectedFolders([selectedFolders.isdir]); % Filter to only directories
    selectedFolders = selectedFolders(~ismember({selectedFolders.name}, {'.', '..'})); % Exclude '.' and '..'

    % Extract animal numbers from folder names
    animalNumbers = cellfun(@(x) extract_animal_number(x), {selectedFolders.name}, 'UniformOutput', false);
    animalNumbers = [animalNumbers{:}]; % Flatten the cell array

    % Display the subfolders with animal numbers
    disp('Veuillez choisir plusieurs paires de sous-dossiers parmi les suivants :');
    for i = 1:length(selectedFolders)
        disp([num2str(animalNumbers(i)) ': ' selectedFolders(i).name]);
    end

    % Ask the user to enter the animal numbers of the subfolder pairs
    pairs_input = input('Entrez les paires de sous-dossiers sous la forme "38(2,3,4,5)" ou "38,2 38,3" : ', 's');
    pairs = parse_pairs(pairs_input, animalNumbers, {selectedFolders.name});
    
    % Initialize lists to store results for all pairs
    chosenSubfolderPairs = {};
    all_DF = {};
    all_ops = {}; 
    all_isort1 = {};
    all_Raster = {};
    all_MAct = {};
    animal_date_list = {};
    directories = {};
    all_prop_MAct = {};
        
    % Process each pair of subfolders
    for pair_idx = 1:size(pairs, 1)
        pair = pairs(pair_idx, :);

        % Find the corresponding indices in selectedFolders for the entered animal numbers
        idx1 = find(animalNumbers == pair(1), 1);
        idx2 = find(animalNumbers == pair(2), 1);

        % Validate that each pair contains exactly two valid indices
        if isempty(idx1) || isempty(idx2)
            error('Choix invalide pour la paire %d. Veuillez entrer des numéros d''animal valides.', pair_idx);
        end

        % Get the paths for the selected subfolders in the current pair
        folderPath1 = fullfile(PathSave, selectedFolders(idx1).name);
        folderPath2 = fullfile(PathSave, selectedFolders(idx2).name);

        % Extract unique date subfolders for both selected folders
        uniqueSubfolders1 = extract_unique_subfolders(folderPath1);
        uniqueSubfolders2 = extract_unique_subfolders(folderPath2);

        % Map numeric date values to folder names
        dateMap1 = create_date_map(uniqueSubfolders1);
        dateMap2 = create_date_map(uniqueSubfolders2);

        disp(['animal ' num2str(pair(1)) ' pour la paire ' num2str(pair(1)) ',' num2str(pair(2)) ':']);
        %display_date_map(dateMap1);
        %disp(['Sous-dossiers de date trouvés dans le dossier correspondant à l''animal ' num2str(pair(2)) ' pour la paire ' num2str(pair(1)) ',' num2str(pair(2)) ':']);
        %display_date_map(dateMap2);

        % Ask user to enter pairs of date subfolders to compare using date numbers
        comparison_input = input('Entrez les dates pour lesquelles vous souhaitez comparer les animaux (ex : "30,31 32,33"), où chaque paire est séparée par un espace : ', 's');
        comparison_pairs_str = strsplit(comparison_input);

        % Initialize array to store valid comparison pairs
        comparison_pairs = [];

        % Process each pair of date subfolders
        for c = 1:length(comparison_pairs_str)
            pair_numbers = str2double(strsplit(comparison_pairs_str{c}, ','));

            % Validate the format of each pair
            if length(pair_numbers) ~= 2
                error('Le format de la paire de sous-dossiers de date est invalide. Veuillez entrer des paires sous forme de "date1,date2".');
            end

            % Validate indices
            if ~isKey(dateMap1, pair_numbers(1)) || ~isKey(dateMap2, pair_numbers(2))
                error('Numéro de date invalide dans la paire : %s', comparison_pairs_str{c});
            end

            % Add valid pair to comparison pairs array
            comparison_pairs = [comparison_pairs; pair_numbers];
        end

        % Check if there are any valid pairs
        if isempty(comparison_pairs)
            error('Aucune paire valide de sous-dossiers de date n''a été entrée.');
        end

        % Process each comparison pair
        for c = 1:size(comparison_pairs, 1)
            % Get the numeric dates for the chosen date subfolders
            date_num1 = comparison_pairs(c, 1);
            date_num2 = comparison_pairs(c, 2);

            % Construct paths for the chosen date subfolders
            chosenPath1 = fullfile(folderPath1, dateMap1(date_num1));
            chosenPath2 = fullfile(folderPath2, dateMap2(date_num2));
            
            % Find the most recent subfolder in the selected date subfolder
            recentSubfolder1 = get_most_recent_subfolder(chosenPath1);
            recentSubfolder2 = get_most_recent_subfolder(chosenPath2);
            
            % Construct final paths to results files
            finalPath1 = fullfile(chosenPath1, recentSubfolder1, 'results_raster.mat');
            finalPath2 = fullfile(chosenPath2, recentSubfolder2, 'results_raster.mat');
            
            results_directories = cell(2,1);
            [results_directories{1}, ~, ~] = fileparts(finalPath1);
            [results_directories{2}, ~, ~] = fileparts(finalPath2);
          
            % Add the chosen subfolder paths to the list
            chosenSubfolderPairs{end+1, 1} = finalPath1;
            chosenSubfolderPairs{end, 2} = finalPath2;

            % Load the 'results_raster.mat' files for the selected subfolders
            results_raster = cell(2,1);
            results_DF = cell(2,1);
	    results_ops = cell(2,1);
            results_isort1 = cell(2,1);
            results_MAct = cell(2,1);
            results_prop_MAct = cell(2,1);
            date_list = cell(2,1);

            for k = 1:2
                subfolderPath = chosenSubfolderPairs{end, k};
                
                if isfile(subfolderPath)
                    disp(['Chargement du fichier : ' subfolderPath]);
                    data = load(subfolderPath);

                    % Check and assign the necessary fields
                    if isfield(data, 'Raster')
                        if isempty(data.Raster)
                            warning('Le champ Raster est vide dans le fichier : %s', subfolderPath);
                        end
                        results_raster{k} = data.Raster;
                    else
                        warning('Le champ Raster est manquant dans le fichier : %s', subfolderPath);
                        results_raster{k} = []; % Default value if missing
                    end

                    if isfield(data, 'DF')
                        if isempty(data.DF)
                            warning('Le champ DF est vide dans le fichier : %s', subfolderPath);
                        end
                        results_DF{k} = data.DF;
                        [NCell, ~] = size(results_DF{k});
                    else
                        warning('Le champ DF est manquant dans le fichier : %s', subfolderPath);
                        results_DF{k} = []; % Default value if missing
                    end

		    if isfield(data, 'ops')
                        if isempty(data.ops)
                            warning('Le champ ops est vide dans le fichier : %s', subfolderPath);
                        end
                        results_ops{k} = data.ops;
                    else
                        warning('Le champ ops est manquant dans le fichier : %s', subfolderPath);
                        results_ops{k} = []; % Default value if missing
                    end

                    if isfield(data, 'isort1')
                        if isempty(data.isort1)
                            warning('Le champ isort1 est vide dans le fichier : %s', subfolderPath);
                        end
                        results_isort1{k} = data.isort1;
                    else
                        warning('Le champ isort1 est manquant dans le fichier : %s', subfolderPath);
                        results_isort1{k} = []; % Default value if missing
                    end

                    if isfield(data, 'MAct')
                        if isempty(data.MAct)
                            warning('Le champ MAct est vide dans le fichier : %s', subfolderPath);
                        end
                        results_MAct{k} = data.MAct;
                        results_prop_MAct{k} = results_MAct{k} / NCell;
                    else
                        warning('Le champ MAct est manquant dans le fichier : %s', subfolderPath);
                        results_MAct{k} = []; % Default value if missing
                        results_prop_MAct{k} = [];
                    end

                    % Create animal_date_list from the subfolder path
                    animal_name = extract_animal_name(fileparts(fileparts(subfolderPath)));
                    recording_date = extract_recording_date(fileparts(fileparts(subfolderPath)));
                    date_list{k} = {animal_name, recording_date};
                else
                    warning('Le fichier results_raster.mat est manquant à : %s', subfolderPath);
                    results_raster{k} = []; % Default value if missing
                end
            end

            % Ensure that results are consistent
            for m = 1:2
                if isempty(results_raster{m})
                    results_raster{m} = results_raster{3-m};
                end

                if isempty(results_DF{m})
                    results_DF{m} = results_DF{3-m};
                end

		if isempty(results_ops{m})
                    results_ops{m} = results_ops{3-m};
                end

                if isempty(results_isort1{m})
                    results_isort1{m} = results_isort1{3-m};
                end

                if isempty(results_MAct{m})
                    results_MAct{m} = results_MAct{3-m};
                end
            end

            % Append results to the final lists
            directories{end+1, 1} = results_directories;
            all_DF{end+1, 1} = results_DF;
	    all_ops{end+1, 1} = results_ops;
            all_isort1{end+1, 1} = results_isort1;
            all_Raster{end+1, 1} = results_raster;
            all_MAct{end+1, 1} = results_MAct;
            all_prop_MAct{end+1, 1} = results_prop_MAct;
            animal_date_list{end+1, 1} = date_list;
        end
    end
end

function pairs = parse_pairs(input_str, valid_animal_numbers, valid_folder_names)
    % Function to parse input string and return valid pairs
    pairs = [];
    % Split input by spaces
    items = strsplit(input_str);

    % Process each item
    for i = 1:length(items)
        if contains(items{i}, '(')
            % Handle cases like 38(2,3,4,5)
            main_part = regexp(items{i}, '^\d+', 'match', 'once');
            sub_part = regexp(items{i}, '\(([^)]+)\)', 'tokens', 'once');
            
            if isempty(main_part) || isempty(sub_part)
                error('Format d''entrée invalide.');
            end
            
            main_number = str2double(main_part);
            if ~ismember(main_number, valid_animal_numbers)
                error('Numéro d''animal invalide : %d', main_number);
            end
            
            sub_numbers = str2double(strsplit(sub_part{1}, ','));
            for j = 1:length(sub_numbers)
                if ~ismember(sub_numbers(j), valid_animal_numbers)
                    error('Numéro d''animal invalide : %d', sub_numbers(j));
                end
                pairs = [pairs; main_number, sub_numbers(j)];
            end
        else
            % Handle cases like 38,2
            pair_numbers = str2double(strsplit(items{i}, ','));
            if length(pair_numbers) ~= 2
                error('Le format de la paire est invalide : %s', items{i});
            end
            if ~ismember(pair_numbers(1), valid_animal_numbers) || ~ismember(pair_numbers(2), valid_animal_numbers)
                error('Numéro d''animal invalide dans la paire : %s', items{i});
            end
            pairs = [pairs; pair_numbers];
        end
    end
end

function mostRecentSubfolder = get_most_recent_subfolder(path)
    % Function to find the most recent subfolder based on timestamp
    subfolders = dir(path);
    subfolders = subfolders([subfolders.isdir]);
    subfolders = subfolders(~ismember({subfolders.name}, {'.', '..'}));

    if isempty(subfolders)
        error('Aucun sous-dossier trouvé dans : %s', path);
    end

    % Sort subfolders by timestamp
    [~, idx] = max([subfolders.datenum]);
    mostRecentSubfolder = subfolders(idx).name;
end

function uniqueSubfolders = extract_unique_subfolders(path)
    % Function to extract unique subfolder names in a given path
    subfolders = dir(path);
    subfolders = subfolders([subfolders.isdir]);
    subfolders = subfolders(~ismember({subfolders.name}, {'.', '..'}));

    uniqueSubfolders = {};
    for i = 1:length(subfolders)
        folderName = subfolders(i).name;
        if ~ismember(folderName, uniqueSubfolders)
            uniqueSubfolders{end+1} = folderName;
        end
    end
end

function dateMap = create_date_map(subfolders)
    % Create a map from numeric date values to folder names
    dateMap = containers.Map('KeyType', 'double', 'ValueType', 'char');
    for i = 1:length(subfolders)
        date_str = regexp(subfolders{i}, '\d+$', 'match', 'once');
        if ~isempty(date_str)
            date_num = str2double(date_str);
            dateMap(date_num) = subfolders{i};
        end
    end
end

function display_date_map(dateMap)
    % Function to display date subfolders with their numeric values
    keys = dateMap.keys();
    for i = 1:length(keys)
        disp(['(' dateMap(keys{i}) ')']);
    end
end

function animal_number = extract_animal_number(folderName)
    % Function to extract the animal number from the folder name
    tokens = regexp(folderName, '(\d+)$', 'tokens');
    if ~isempty(tokens)
        animal_number = str2double(tokens{1}{1});
    else
        animal_number = NaN;
    end
end

function animal_name = extract_animal_name(subfolderPath)
    % Function to extract the animal name from the subfolder path
    parts = strsplit(subfolderPath, filesep);
    animal_name = parts{end-1}; % Assuming the animal name is at this position
end

function recording_date = extract_recording_date(subfolderPath)
    % Function to extract the recording date from the subfolder path
    parts = strsplit(subfolderPath, filesep);
    recording_date = parts{end}; % Assuming the date is at this position
end