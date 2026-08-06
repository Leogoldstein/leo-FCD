function selected_groups = create_data(selected_groups)

    if nargin < 1 || isempty(selected_groups)
        return;
    end

    empty_data = struct( ...
        'motion',          struct(), ...
        'stim',            struct(), ...
        'gcamp_plane',     struct(), ...
        'electroporated_plane',      struct(), ...
        'combined_plane',  struct());

    type_names = fieldnames(selected_groups);

    for t = 1:numel(type_names)

        current_type = type_names{t};

        for k = 1:numel(selected_groups.(current_type))

            if ~isfield(selected_groups.(current_type)(k), 'data') || ...
                    isempty(selected_groups.(current_type)(k).data)

                selected_groups.(current_type)(k).data = empty_data;

            end

        end
    end
end