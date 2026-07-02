clear
clc

%% ===================== Parameters =====================
micronsPerPixel = 4.0952;
sliceSpacing_um = 100;

files = { ...
    'C:\Users\goldstein\Desktop\1743_1\Results.csv', ...
    'C:\Users\goldstein\Desktop\1743_2\Results.csv'};

%% ===================== Load data =====================
allX = [];
allY = [];
allSlice = [];

globalSlice = 1;

for f = 1:numel(files)

    T = readtable(files{f});
    T.Type = string(T.Type);

    % Keep only detected cells
    T = T(T.Type=="Traced",:);

    localSlices = unique(T.Pos);

    for s = 1:numel(localSlices)

        idx = T.Pos==localSlices(s);

        allX = [allX; T.X(idx)];
        allY = [allY; T.Y(idx)];
        allSlice = [allSlice; repmat(globalSlice,sum(idx),1)];

        globalSlice = globalSlice + 1;

    end

end

%% ===================== Compute metrics =====================
slices = unique(allSlice);

nSlices = numel(slices);

NumCells = NaN(nSlices,1);
Extent_px2 = NaN(nSlices,1);
Extent_mm2 = NaN(nSlices,1);
Density = NaN(nSlices,1);

for i = 1:nSlices

    idx = allSlice==slices(i);

    x = allX(idx);
    y = allY(idx);

    NumCells(i) = numel(x);

    if numel(x)<3
        continue
    end

    k = convhull(x,y);

    Extent_px2(i) = polyarea(x(k),y(k));

    Extent_mm2(i) = Extent_px2(i)*(micronsPerPixel^2)/1e6;

    Density(i) = NumCells(i)/Extent_mm2(i);

end

%% ===================== Distance =====================
Distance_um = (0:nSlices-1)'*sliceSpacing_um;

%% ===================== Summary table =====================
summaryTable = table( ...
    Distance_um,...
    slices,...
    NumCells,...
    Extent_mm2,...
    Density,...
    'VariableNames', ...
    {'Distance_um',...
    'Slice',...
    'NumCells',...
    'Extent_mm2',...
    'Density_cells_per_mm2'});

disp(summaryTable)

writetable(summaryTable,...
    'C:\Users\goldstein\Desktop\1743_combined_summary.csv');

%% ===================== Figure 1 =====================
figure

plot(Distance_um, Extent_mm2, '-o', ...
    'LineWidth', 3, ...
    'MarkerSize', 10);

xlabel('Distance from the first section (\mum)', ...
    'FontSize', 24, 'FontWeight', 'bold');

ylabel('Extent of electroporated cell cloud (mm^2)', ...
    'FontSize', 24, 'FontWeight', 'bold');

title('Spatial extent of mTOR-electroporated cells', ...
    'FontSize', 32, 'FontWeight', 'bold');

set(gca, ...
    'FontSize', 20, ...      % taille des valeurs des axes
    'FontWeight', 'bold', ...
    'LineWidth', 2, ...
    'TickLength', [0.02 0.02]);

grid on
box off

% %% ===================== Figure 2 =====================
% figure
% 
% plot(Distance_um,Density,'-o',...
%     'LineWidth',2,...
%     'MarkerSize',8)
% 
% xlabel('Distance from the first section (\mum)')
% ylabel('Electroporated cell density (cells/mm^2)')
% title('Spatial density of mTOR-electroporated cells')
% 
% grid on
% box off
% 
% %% ===================== Figure 3 =====================
% figure
% 
% yyaxis left
% 
% plot(Distance_um,Extent_mm2,'-o',...
%     'LineWidth',2,...
%     'MarkerSize',8)
% 
% ylabel('Extent (mm^2)')
% 
% yyaxis right
% 
% plot(Distance_um,Density,'-s',...
%     'LineWidth',2,...
%     'MarkerSize',8)
% 
% ylabel('Density (cells/mm^2)')
% 
% xlabel('Distance from the first section (\mum)')
% title('Spatial extent and density of mTOR-electroporated cells')
% 
% grid on
% box off
% 
% %% === Figure 4 ===
% 
% figure;
% scatter3( ...
%     allY*micronsPerPixel, ...
%     (allSlice-1)*sliceSpacing_um, ...
%     allX*micronsPerPixel, ...
%     10, ...
%     (allSlice-1)*sliceSpacing_um, ...
%     'filled');
% 
% xlabel('Y position (\mum)');
% ylabel('Distance from first section (\mum)');
% zlabel('Y position (\mum)');
% 
% title('3D distribution of mTOR-electroporated cells');
% 
% grid on;
% box on;
% axis vis3d;
% view(3);
% 
% cb = colorbar;
% cb.Label.String = 'Distance from first section(\um)';