function [selected_groups, daytime] = create_gcamp_output_folders(selected_groups)

    if nargin < 1 || isempty(selected_groups)
        daytime = '';
        return;
    end

    daytime = datestr(datetime('now'), 'yy_mm_dd_HH_MM');

    processing_choice1 = input('Do you want to process the most recent folder for processing (1/2)? ', 's');

    if strcmp(processing_choice1, '2')
        processing_choice2 = input('Do you want to select an existing folder or create a new one? (1/2): ', 's');
    else
        processing_choice2 = [];
    end

    type_names = fieldnames(selected_groups);

    for t = 1:numel(type_names)

        current_type = type_names{t};

        for k = 1:numel(selected_groups.(current_type))

            current_animal_group = selected_groups.(current_type)(k).animal_group;

            if isfield(selected_groups.(current_type)(k), 'paths') && ...
               isfield(selected_groups.(current_type)(k).paths, 'date')

                date_group_paths = selected_groups.(current_type)(k).paths.date;
            else
                date_group_paths = {};
            end

            if isrow(date_group_paths)
                date_group_paths = date_group_paths(:);
            end

            nDates = numel(date_group_paths);

            if isfield(selected_groups.(current_type)(k), 'paths') && ...
               isfield(selected_groups.(current_type)(k).paths, 'suite2p') && ...
               ~isempty(selected_groups.(current_type)(k).paths.suite2p)

                current_suite2p_group = selected_groups.(current_type)(k).paths.suite2p;
            else
                current_suite2p_group = cell(nDates, 4);
            end

            current_suite2p_group = force_4col(current_suite2p_group, nDates);

            current_gcamp_folders_group = current_suite2p_group(:, 1);

            [gcamp_root_folders, gcamp_output_folders] = create_base_folders( ...
                date_group_paths, ...
                current_gcamp_folders_group, ...
                daytime, ...
                processing_choice1, ...
                processing_choice2, ...
                current_animal_group);

            selected_groups.(current_type)(k).paths.gcamp_root = gcamp_root_folders;
            selected_groups.(current_type)(k).paths.gcamp_output = gcamp_output_folders;
        end
    end
end

function C4 = force_4col(C, nRowsWanted)

    if nargin < 2
        if isempty(C)
            nRowsWanted = 0;
        else
            nRowsWanted = size(C,1);
        end
    end

    if isempty(C)
        C4 = cell(nRowsWanted, 4);
        return;
    end

    nRows = size(C,1);
    nCols = size(C,2);

    C4 = cell(max(nRows, nRowsWanted), 4);
    C4(1:nRows, 1:min(4,nCols)) = C(:, 1:min(4,nCols));
end