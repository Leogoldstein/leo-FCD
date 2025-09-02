% === 1. Charger les deux CSV ===
roiTable = readtable('C:\Users\goldstein\Desktop\Results.csv');         % ROI info
measureTable = readtable('C:\Users\goldstein\Desktop\Results-1.csv');   % Area info

% === 2. Exclure les ROIs de la slice 2 ===
roiTable = roiTable(roiTable.Pos ~= 2, :);

% === 3. Filtrer types ===
isFreehand = strcmp(roiTable.Type, 'Freehand');
isTraced = strcmp(roiTable.Type, 'Traced');

% === 4. Extraire les slices restantes ===
slices = unique(roiTable.Pos);
ratios = NaN(length(slices),1);  % init des ratios

for i = 1:length(slices)
    slice = slices(i);
    
    % ---- Trouver Freehand correspondant ----
    sliceStr = sprintf('%04d-', slice);  % pattern du nom, ex: '0003-'
    idxFh = find(isFreehand & startsWith(roiTable.Name, sliceStr));
    
    if isempty(idxFh)
        continue;
    end
    
    nameFh = roiTable.Name{idxFh(1)};
    
    % ---- Chercher Area correspondante ----
    pattern = strcat(':', nameFh, ':');
    matchIdx = contains(measureTable.Label, pattern);
    
    if any(matchIdx)
        area = measureTable.Area(matchIdx);
    else
        area = NaN;
    end

    % ---- Nombre de ROIs Traced pour ce slice ----
    nTraced = sum(isTraced & roiTable.Pos == slice);
    
    % ---- Calcul du ratio ----
    if ~isnan(area) && area > 0
        ratios(i) = nTraced / area;
    end
end

% === 5. Affichage ===
figure;
plot(slices, ratios, '-o', 'LineWidth', 2, 'MarkerSize', 6);
xlabel('Numéro de coupe');
ylabel('Ratio nb de cellules électroporées / taille dysplasie"');
title("Evolution de la densité des cellules électroporées mtor en fonction du numéro de coupe");
grid on;
