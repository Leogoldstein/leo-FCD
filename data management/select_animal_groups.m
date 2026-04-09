function selected_indices = select_animal_groups(selected_groups)
    % Récupère tous les noms de groupes disponibles
    all_groups = {selected_groups.animal_group};
    
    % Affiche la liste
    fprintf('--- Available animal groups ---\n');
    for i = 1:length(all_groups)
        fprintf('%d: %s\n', i, all_groups{i});
    end
    fprintf('Type "all" to process every group.\n');
    
    % Demande à l’utilisateur de choisir
    user_input = input('Select animal group(s) by name, number(s), or "all": ', 's');
    
    % Cas "all"
    if strcmpi(user_input, 'all')
        selected_indices = 1:length(selected_groups);
        return;
    end
    
    % Si l’utilisateur donne des numéros séparés par des espaces
    if all(ismember(user_input, '0123456789 '))
        selected_indices = str2num(user_input); %#ok<ST2NM>
        return;
    end
    
    % Sinon, comparer les noms (supporte plusieurs séparés par espace)
    user_groups = strsplit(strtrim(user_input));
    selected_indices = find(ismember(all_groups, user_groups));
    
    if isempty(selected_indices)
        error('No valid groups found matching your input.');
    end
end
