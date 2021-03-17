classdef srtplayer
    % A MATLAB class that plays movie subtitles in a window from .srt file.
    %
    % Written by Kouichi C. Nakamura Ph.D.
    % MRC Brain Network Dynamics Unit
    % University of Oxford
    % kouichi.c.nakamura@gmail.com
    % 16-Mar-2021 08:17:57

    properties
        srtpath (1,:) char
        T table
        Width  (1,1) double 
        MarginBottom (1,1) double = 50
        BackgroundColor (1,:) char {mustBeMember(BackgroundColor,{'black','white'})} = 'black';
    end
    
    methods
        function obj = srtplayer(srtpath)
            % Constructor of srtplayer class
            %
            % SYNTAX
            % obj = srtplayer(srtpath)
            %
            % INPUT ARGUMENTS
            % srtpath     char
            %             File path of a *.srt subtitle file.
            %
            %
            % OUTPUT ARGUMENTS
            % obj         srtviewer object
            %
            % Written by Kouichi C. Nakamura Ph.D.
            % MRC Brain Network Dynamics Unit
            % University of Oxford
            % kouichi.c.nakamura@gmail.com
            % 16-Mar-2021 08:17:57
            %
            % See also
            % filereadAsString
            % ismatched
            
            arguments
                
                srtpath (1,:) char
                
            end
            
            assert(isfile(srtpath))
            
            assert(endsWith(srtpath, '.srt'))
                       
            obj.srtpath = srtpath;
           
            s = filereadAsString(srtpath);
            
            s2d = @str2double;

            maxind = find(ismatched(s, "^[" + char(65279) + "]?\d+$"),1,'last');
            N = s2d(s(maxind));

            from = cell(N,1);
            to = cell(N,1);
            str = cell(N,1);
            
            ind1 = find(ismatched(s, "^[" + char(65279) + "]?1$"),1,'first');

            ind2 = find(ismatched(s, "^[" + char(65279) + "]?\d+$"));
            ind3 = find(s == "") + 1;
            inds = [ind1; intersect(ind2, ind3)];
            
            f = waitbar(0,'Loading data','Name','srtplayer');
            j = 0;
            for i = 1:N
                
                if i/N*100 > j
                    waitbar(i/N);
                    j = j + 1;
                end
                
                ind = inds(i);
                
                t1t2 = regexp(s(ind+ 1), ...
                    '^(\d{2}):(\d{2}):(\d{2}),(\d{3}) --> (\d{2}):(\d{2}):(\d{2}),(\d{3})$',...
                    'tokens','once');
                
                from{i} = hours(s2d(t1t2{1})) + minutes(s2d(t1t2{2})) + ...
                    seconds(s2d(t1t2{3})) + milliseconds(s2d(t1t2{4}));
                
                to{i} = hours(s2d(t1t2{5})) + minutes(s2d(t1t2{6})) + ...
                    seconds(s2d(t1t2{7})) + milliseconds(s2d(t1t2{8}));
               
                
                str{i} = s(ind + 2:find(s(ind:end) == "",1,'first') + ind - 2);

            end
            close(f);
            
            T = table(vertcat(from{:}), vertcat(to{:}), str,...
                'VariableNames',{'from','to','subtitle'});
            
            obj.T = T;
            
            ss = get(0,'ScreenSize');

            obj.Width = ss(3);
            
            
            
        end
        
        function run(obj)
            % The main method of srtviewer class
            %
            % SYNTAX
            % run(obj), obj.run
            %
            % See also
            % timer
            % uislider
            % uilabel
            % uibutton

            arguments
                obj
            end
            
            [~,name,~] = fileparts(obj.srtpath);
                        
            switch obj.BackgroundColor
                case 'black'
                    BGcolor = 'k';
                    Fontcolor = 'w';
                case 'white'
                    BGcolor = [0.9400    0.9400    0.9400];
                    Fontcolor = 'k'; 
            end
                
            fig = uifigure('WindowStyle','modal','Position',[0, obj.MarginBottom, obj.Width, 100],...
                'Name', name,'Color',BGcolor);
            
            
            timeindicator = uilabel(fig, 'WordWrap', 'off',...
                'Position',[195 45 100 50], ...
                'HorizontalAlignment','left', ...
                'FontSize',16,'FontColor',Fontcolor);
            timeindicator.Text = '00:00:00.000';
            
            sbt = uilabel(fig, 'WordWrap', 'on',...
                'Position',[300, 30, obj.Width - 300, 70], ...
                'HorizontalAlignment','center', ...
                'VerticalAlignment','center',...
                'FontSize',16,'FontColor',Fontcolor);
            
           sbt.Text =name;
            
            
            warning off
            sld = uislider('Position',[20, 10, obj.Width-40, 20],'Parent', fig,...
                'FontColor',Fontcolor,...
                'ValueChangedFcn',@slidermoved);
            warning on
            sld.Limits = [0, minutes(max(obj.T.from))];
            sld.MajorTicks = [];
            sld.MinorTicks = [];
            
            bt_play = uibutton(fig,'Text','Play','Position', [10 50 40 40],...
                'Interruptible','on',...
                'FontColor',Fontcolor,...
                'BackgroundColor',BGcolor,...
                'ButtonPushedFcn',@playButtonPushed);

            bt_stop = uibutton(fig,'Text','Stop','Position', [55 50 40 40],...
                'FontColor',Fontcolor,...
                'BackgroundColor',BGcolor,...
                'ButtonPushedFcn',@stopButtonPushed);

            bt_jump = uibutton(fig,'Text','Jump','Position', [100 50 40 40],...
                'FontColor',Fontcolor,...
                'BackgroundColor',BGcolor,...
                'ButtonPushedFcn', @jumpButtonPushed);
            
            bt_left = uibutton(fig,'Text','<','Position', [145 50 20 40],...
                'FontColor',Fontcolor,...
                'BackgroundColor',BGcolor,...                
                'ButtonPushedFcn', @leftButtonPushed);

            bt_right = uibutton(fig,'Text','>','Position', [170 50 20 40],...
                'FontColor',Fontcolor,...
                'BackgroundColor',BGcolor,...
                'ButtonPushedFcn', @rightButtonPushed);

            
            t = timer;
            
            t0 = datetime;
            slidertime_s = sld.Value*60;
            
            function slidermoved(~,~)
                
                t1 = minutes(sld.Value);
                
                tf =  t1 >= obj.T.from & t1 < obj.T.to;
                if any(tf)
                    if nnz(tf) == 1
                        nl = length(obj.T.subtitle{tf});
                        
                        expr = ['%s', repmat('\n%s', 1, nl - 1)];
                        
                        sbt.Text = sprintf(expr,obj.T.subtitle{tf});
                        
                    else
                        error('unexpected')
                    end
                else
                    sbt.Text = "";
                end
                
                if isvalid(t) && t.Running == "on"
                    stop(t)
                    playButtonPushed;

                else
                    timeindicator.Text = datestr(minutes(sld.Value),'HH:MM:SS.FFF');

                end
                
                
                
                
            end
            
            function leftButtonPushed(~,~)
                
                leftright(-1);
                
            end
            
            function rightButtonPushed(~,~)
                
                leftright(1);

            end
            
            function leftright(direction)
                
               
                t1 = minutes(sld.Value);

                ind = find(t1 >= obj.T.from,1,'last');
                if isempty(ind)
                    ind = 1;
                end
                    
                if ind+direction >= 1 && ind+direction < height(obj.T)
                    sld.Value = minutes(obj.T.from(ind+direction));
                    
                    timeindicator.Text = datestr(obj.T.from(ind+direction),'HH:MM:SS.FFF');
                    
                    nl = length(obj.T.subtitle{ind+direction});
                    expr = ['%s', repmat('\n%s', 1, nl - 1)];
                    sbt.Text = sprintf(expr,obj.T.subtitle{ind+direction});
                    
                    t0 = datetime - obj.T.from(ind+direction);
                    
                end

                  
                
            end
            
            
            function playButtonPushed(~,~)
           
                slidertime_s = sld.Value*60;
                
                delete(t);
                
                t = timer;
                t.TimerFcn = @(~,~) timerFcn();
                t.ExecutionMode = 'fixedRate';
                t.TasksToExecute = Inf;
                t.Period = 0.1; % 10 Hz

                t.TasksToExecute = ceil((seconds(max(obj.T.to)) - slidertime_s)/t.Period);

                t0 = datetime - seconds(slidertime_s);

                start(t);
                
            end
            
            function timerFcn()
                t1 = datetime - t0;
                sld.Value = minutes(t1); % update slider
                
                timeindicator.Text = datestr(t1,'HH:MM:SS.FFF');
                
                tf =  t1 >= obj.T.from & t1 < obj.T.to;
                if any(tf)
                    if nnz(tf) == 1
                        nl = length(obj.T.subtitle{tf});
                            
                            expr = ['%s', repmat('\n%s', 1, nl - 1)];
                        
                            sbt.Text = sprintf(expr,obj.T.subtitle{tf});
                        
                    else
                        error('unexpected')
                    end
                else
                    sbt.Text = "";
                end
                
            end
            
            function stopButtonPushed(~,~)
                
                stop(t);
                delete(t);
                
            end
            
            function jumpButtonPushed(~,~)
                
                answer = inputdlg({'Hours','Minutes (0-60)','Seconds (0-60)','Milliseconds (0-1000)'},'Jump to');
                
                if isempty(answer{1})
                    h = hours(0);
                else
                    h = hours(str2double(answer{1}));
                end
                
                
                if isempty(answer{2})
                    m = minutes(0);
                else
                    m = minutes(str2double(answer{2}));
                end
                
                if isempty(answer{3})
                    s = seconds(0);
                else
                    s = seconds(str2double(answer{3}));
                end
                
                if isempty(answer{4})
                    ms = milliseconds(0);
                else
                    ms = milliseconds(str2double(answer{4}));
                end
                
                time = h + m + s + ms;
                
                if time < 0
                    sld.Value = 0;
                    if isvalid(t)
                        t0 = datetime;
                    end
                elseif time > max(obj.T.to)
                    sld.Value = minutes(max(obj.T.to));
                    if isvalid(t)
                        stop(t);
                    end
                else
                    sld.Value = minutes(time);
                    t0 = datetime - time;
                end
                
            end
            
        end
            
        function showSubtitles(obj)
            
            [~, name, ~] = fileparts(obj.srtpath);
            
            fig = uifigure('Name', name);
                        
            uit = uitable(fig,'Position',[0, 0, fig.Position(3), fig.Position(4)]);
            
            from = obj.T.from;
            
            subtitles = obj.T.subtitle;
            
            nlines = cellfun(@(x) numel(x), subtitles);
            
            n = sum(nlines);
            
            
            Subtitles = vertcat(subtitles{:});
            
            
            h = floor(hours(from));
            
            m = floor(minutes(from - hours(h)));
            
            s = floor(seconds(from - hours(h) - minutes(m)));
            
            C = cell(length(from),1);
            for i = 1:length(from)
                C{i} = [sprintf("%d:%02d:%02d",h(i),m(i),s(i));...
                    strings(nlines(i) -1, 1)];

            end
            
            Time = vertcat(C{:});
            
            Tdata = table(Time, Subtitles);
            
            uit.Data = Tdata;
            uit.ColumnWidth = {fig.Position(3)*0.10,fig.Position(3)*0.90};

        end
    end
end


%--------------------------------------------------------------------------
        
function str = filereadAsString(filename)
% filereadAsString reads text file as string column vector. Convienent when
% you want to edit an existing text file.
%
% SYNTAX
% str = filereadAsString(filename)
%
%
% INPUT ARGUMENTS
% filename    char row vector | string scalar
%             File name (relative of absolute path) of a text file.
%
%
% OUTPUT ARGUMENTS
% str         string column vector
%             str contains the all the lines of filename without the
%             newline characters.
%
% EXAMPLE
% Open a CSV file and delete NaNs.
%
% CSV = filereadAsString('XXXX.csv');
%
% CSV_ = regexprep(CSV,'NaN','');
%
% fid = fopen('XXXX.csv','w','n','UTF-8');
% 
% for i = 1:length(CSV)
%     fprintf(fid,"%s\n", CSV_(i));
% end
% 
% fclose(fid);
%
%
%
% Written by Kouichi C. Nakamura Ph.D.
% MRC Brain Network Dynamics Unit
% University of Oxford
% kouichi.c.nakamura@gmail.com
% 16-Sep-2019 18:22:00
%
%
% See also
% fgetl, fileread, readtable, textscan, fscanf

fid = fopen(filename,'r','n','UTF-8');

tline = cell(0,1);

while 1
    tline{end+1,1} = fgetl(fid); %#ok<AGROW>
    if isnumeric(tline{end,1})
        break
    end
end

fclose(fid);

tline(end,:) = [];

str = string(tline);


end

function TF = ismatched(str, expression)
% ismatched is a wrapper of regexp function that returns logical
% array whose element is true when there is at least one match for each
% element of str. This one works with the syntax [startIndex = regexp(str,
% expression)].
%
% The builtin function "matches" serve for a similar purpose, but
% "ismatched" works with regular expressions while "matches" doesn't.
%
% TF = ismatched(str, expression)
%
% str    input text
%        char | cell array of strings | string array | categorical array
%        Otherwise TF is an array of false whose size is the same as str
%
% expression
%        regular expression
%        char | cell array of strings
%
% TF     logical array
%
%
% Does not support 'outkey' option of regexp
%
%
% EXAMPLES
% * Cell array and char
% ismatched({'kjx127j02@0-1200.mat';'kjx127b03@0-1200.mat'},'127b03')
% ans =
%      0
%      1
%
% * char and cell array
% ismatched('kjx127j02@0-1200.mat', {'^kjx127j', 'kjx127b'})
% ans =
%      1   0
%
% * Cell array and cell array (matching length)
% ismatched({'kjx127j02@0-1200.mat';'kjx127b03@0-1200.mat'}, {'^kjx127j', 'kjx127X'})
% ans =
%      1   0
%
%
% Written by
% Kouichi C. Nakamura, Ph.D
% Kyoto University
% Dec 2015
% kouichi.c.nakamura@gmail.com
%
%
% See also
% matches, ismatchedany, contains, startsWith, endsWith, strcmp, strcmpi, regexp

narginchk(2,2);

if iscellstr(str) || ischar(str) || isstring(str) || iscategorical(str)
    if iscategorical(str)
        str = cellstr(str);
    end

    startIndex = regexp(str, expression);
    % startIndex
    % row vector | cell array of row vectors

    if isnumeric(startIndex)
        TF = ~isempty(startIndex);
    elseif iscell(startIndex)
        TF = cellfun(@(x) ~isempty(x), startIndex);
    end

else
    error('str is in a wrong data type: %s', class(str))
end

end
