function [choices, group_order] = choose_group_selection()
% choose_group_selection
% Gère uniquement le choix utilisateur des groupes à traiter.
%
% Outputs:
%   choices     : vecteur numérique des choix utilisateur
%                 1 = JM
%                 2 = FCD
%                 3 = WT
%                 4 = SHAM
%   group_order : ordre des groupes

    group_order = {'jm', 'FCD', 'WT', 'SHAM'};

    disp('Please choose one or more folders to process:');
    disp('1 : JM (.npy data)');
    disp('2 : FCD (Fall.mat data)');
    disp('3 : WT (Fall.mat data)');
    disp('4 : SHAM (Fall.mat data)');

    user_input = input('Enter your choice (e.g., 1 2): ', 's');
    choices = str2double(strsplit(strtrim(user_input)));

    if isempty(choices) || any(isnan(choices)) || any(~ismember(choices, [1, 2, 3, 4]))
        error('Choix invalide. Veuillez choisir une ou plusieurs valeurs parmi 1, 2, 3, 4.');
    end

    choices = unique(choices, 'stable');
end