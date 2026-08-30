base=fileparts(mfilename('fullpath'));
figdir=fullfile(base,'figures');
if ~exist(figdir,'dir'),mkdir(figdir);end
addpath(fullfile(base,'..','code'));
D=data_a();

S=load(fullfile(base,'..','result','problem5.mat'));
f=figure('Color','w','Position',[100 100 1080 620]); hold on; grid on; box on;
col=lines(5);
for k=1:5
    id=find(S.bombs(:,1)==k);
    if isempty(id),continue;end
    tt=linspace(0,max(S.C.tb(id)),100)';
    e=[cosd(S.routes(k,1)),sind(S.routes(k,1)),0];
    xyz=D.u0(k,:)+S.routes(k,2)*tt.*e;
    plot3(xyz(:,1),xyz(:,2),xyz(:,3),'LineWidth',1.8,'Color',col(k,:), ...
        'DisplayName',sprintf('FY%d航迹',k));
    scatter3(S.C.burst(id,1),S.C.burst(id,2),S.C.burst(id,3),48,col(k,:), ...
        'filled','HandleVisibility','off');
end
mc=[.15 .15 .15;.45 .45 .45;.70 .25 .15];
for j=1:3
    tt=linspace(0,D.T(j),120)'; e=-D.m0(j,:)/norm(D.m0(j,:));
    xyz=D.m0(j,:)+D.vm*tt.*e;
    plot3(xyz(:,1),xyz(:,2),xyz(:,3),'--','Color',mc(j,:), ...
        'LineWidth',1.3,'DisplayName',sprintf('M%d轨迹',j));
end
scatter3(nan,nan,nan,48,'k','filled','DisplayName','烟幕起爆点');
scatter3(0,200,5,90,'r','p','filled','DisplayName','真目标');
xlabel('x/m');ylabel('y/m');zlabel('z/m');
view(38,24); axis tight;
legend('Location','eastoutside','NumColumns',1);
exportgraphics(f,fullfile(figdir,'trajectory_p5.png'),'Resolution',300); close(f);

I=coverage_intervals(S.routes,S.bombs,1:3,D,.01);
f=figure('Color','w','Position',[100 100 900 360]); hold on; box on;
cc=lines(3);
for j=1:3
    a=I(j).covered;
    for r=1:size(a,1)
        rectangle('Position',[a(r,1),4-j,a(r,2)-a(r,1),.55], ...
            'FaceColor',cc(j,:),'EdgeColor','none');
    end
end
yticks([1.275 2.275 3.275]);yticklabels({'M3','M2','M1'});
xlabel('时间/s');
xlim([0 40]);ylim([.8 4]);grid on;
exportgraphics(f,fullfile(figdir,'intervals_p5.png'),'Resolution',300); close(f);

S4=load(fullfile(base,'..','result','problem4.mat'));
f=figure('Color','w','Position',[100 100 720 430]);
v=[S4.single_time;S4.t_full]';
b=bar(v,'FaceColor','flat');
b.CData(1:3,:)=repmat([.20 .50 .75],3,1);
b.CData(4,:)=[.90 .40 .10];
set(gca,'XTickLabel',{'FY1单弹','FY2单弹','FY3单弹','联合方案'});
ylabel('有效遮蔽时间/s');grid on;ylim([0 12.5]);
text(1:4,v+.22,compose('%.3f',v),'HorizontalAlignment','center');
exportgraphics(f,fullfile(figdir,'problem4_bar.png'),'Resolution',300); close(f);

S3=load(fullfile(base,'..','result','problem3.mat'));
I3=coverage_intervals(S3.routes,S3.bombs,1,D,.01);
f=figure('Color','w','Position',[100 100 820 360]);hold on;box on;
cc=lines(4);
for i=1:3
    Ii=coverage_intervals(S3.routes,S3.bombs(i,:),1,D,.01);
    a=Ii.covered;
    for r=1:size(a,1)
        rectangle('Position',[a(r,1),4.05-i,a(r,2)-a(r,1),.38], ...
            'FaceColor',cc(i,:),'EdgeColor','none');
    end
end
a=I3.covered;
for r=1:size(a,1)
    rectangle('Position',[a(r,1),.75,a(r,2)-a(r,1),.38], ...
        'FaceColor',cc(4,:),'EdgeColor','none');
end
ylim([.6 3.7]);yticks([.94 1.24 2.24 3.24]);
yticklabels({'联合','弹3','弹2','弹1'});grid on;
xlabel('时间/s');xlim([0 8]);
text(.25,1.24,'0 s（无独立遮蔽）','Color',[.35 .35 .35], ...
    'VerticalAlignment','middle');
exportgraphics(f,fullfile(figdir,'intervals_p3.png'),'Resolution',300);close(f);

R=load(fullfile(base,'..','result','sensitivity.mat'));
f=figure('Color','w','Position',[100 100 760 420]);
histogram(sum(R.sample,2),12,'FaceColor',[.20 .50 .75],'EdgeColor','w');
xline(R.stat.total(1),'r--','基准值','LineWidth',1.4, ...
    'LabelOrientation','horizontal','LabelVerticalAlignment','middle', ...
    'LabelHorizontalAlignment','left');
xline(R.stat.total(2),'k-.','扰动均值','LineWidth',1.4, ...
    'LabelOrientation','horizontal','LabelVerticalAlignment','top', ...
    'LabelHorizontalAlignment','left');
xlabel('三枚导弹总遮蔽时间/s');ylabel('频数');
grid on;
yl=ylim;text(min(sum(R.sample,2))+.3,.92*yl(2),'n=100','FontWeight','bold');
exportgraphics(f,fullfile(figdir,'sensitivity_hist.png'),'Resolution',300);close(f);

C=load(fullfile(base,'..','result','convergence.mat'));
coarse=zeros(5,1);fine=zeros(5,1);
for p=1:5
    coarse(p)=sum(C.conv{p}(1,1,:));
    fine(p)=sum(C.conv{p}(3,3,:));
end
f=figure('Color','w','Position',[100 100 760 430]);
err=abs(coarse-fine);
bar(1:5,err,.62,'FaceColor',[.20 .50 .75]);grid on;
xticks(1:5);xticklabels({'问题1','问题2','问题3','问题4','问题5'});
ylabel('粗、精网格绝对差/s');ylim([0 .07]);
text(1:5,err+.002,compose('%.3f',err),'HorizontalAlignment','center');
exportgraphics(f,fullfile(figdir,'convergence.png'),'Resolution',300); close(f);
