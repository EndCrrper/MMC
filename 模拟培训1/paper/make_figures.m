base=fileparts(mfilename('fullpath'));
figdir=fullfile(base,'figures');
if ~exist(figdir,'dir'),mkdir(figdir);end
addpath(fullfile(base,'..','code'));
D=data_a();

S=load(fullfile(base,'..','result','problem5.mat'));
f=figure('Color','w','Position',[100 100 900 620]); hold on; grid on; box on;
col=lines(5);
for k=1:5
    id=find(S.bombs(:,1)==k);
    if isempty(id),continue;end
    tt=linspace(0,max(S.C.tb(id)),100)';
    e=[cosd(S.routes(k,1)),sind(S.routes(k,1)),0];
    xyz=D.u0(k,:)+S.routes(k,2)*tt.*e;
    plot3(xyz(:,1),xyz(:,2),xyz(:,3),'LineWidth',1.7,'Color',col(k,:));
    scatter3(S.C.burst(id,1),S.C.burst(id,2),S.C.burst(id,3),45,col(k,:),'filled');
end
for j=1:3
    tt=linspace(0,D.T(j),120)'; e=-D.m0(j,:)/norm(D.m0(j,:));
    xyz=D.m0(j,:)+D.vm*tt.*e;
    plot3(xyz(:,1),xyz(:,2),xyz(:,3),'k--','LineWidth',1.1);
end
scatter3(0,200,5,80,'r','p','filled');
xlabel('x/m');ylabel('y/m');zlabel('z/m');
title('问题5无人机航迹、导弹轨迹与烟幕起爆点');
view(38,24); axis tight;
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
xlabel('时间/s');title('问题5三枚导弹的有效遮蔽区间');
xlim([0 max(D.T)]);ylim([.8 4]);grid on;
exportgraphics(f,fullfile(figdir,'intervals_p5.png'),'Resolution',300); close(f);

S4=load(fullfile(base,'..','result','problem4.mat'));
f=figure('Color','w','Position',[100 100 720 430]);
bar([S4.single_time;S4.t_full]','FaceColor','flat');
set(gca,'XTickLabel',{'FY1单弹','FY2单弹','FY3单弹','联合方案'});
ylabel('有效遮蔽时间/s');title('问题4单弹贡献与联合遮蔽效果');grid on;
exportgraphics(f,fullfile(figdir,'problem4_bar.png'),'Resolution',300); close(f);

C=load(fullfile(base,'..','result','convergence.mat'));
coarse=zeros(5,1);fine=zeros(5,1);
for p=1:5
    coarse(p)=sum(C.conv{p}(1,1,:));
    fine(p)=sum(C.conv{p}(3,3,:));
end
f=figure('Color','w','Position',[100 100 760 430]);
plot(1:5,coarse,'o-','LineWidth',1.5);hold on;
plot(1:5,fine,'s-','LineWidth',1.5);grid on;
xticks(1:5);xticklabels({'问题1','问题2','问题3','问题4','问题5'});
ylabel('有效遮蔽时间/s');legend('粗网格','精细网格','Location','northwest');
title('时间步长与目标采样收敛结果');
exportgraphics(f,fullfile(figdir,'convergence.png'),'Resolution',300); close(f);
