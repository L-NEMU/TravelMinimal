# TravelMinimal
一个交互极简的软件，可以进行旅行记录和导出
A software with an extremely simple interface that enables travel record-keeping and export.

File1-TravelMinimal
-App
  -AppRouter
  项目的页面路由枚举文件，统一管理App内所有可跳转的页面标识，规范页面导航逻辑。
  -RootTabView
  基于SwiftUI实现的App的底部标签栏主容器页面，是整个软件的核心首页框架，承载4个核心业务页面，实现底部Tab切换浏览。
-Core
  -Models
  项目的核心数据模型文件，定义了旅行日志、消费记录、归档记录的完整数据结构，同时实现了序列化、可识别、可对比能力，是整个App的数据底层支撑。
  -Store
  项目的全局数据仓库、负责旅行数据的存储、读取、全局共享，导出。
-Features
  -Calendar
  App的旅行日历页面，能够实现日历视图展示、日期范围选择、按日期查看旅行日志功能。
  -During
  旅行中页面，集成了地图、每日花销、预算统计、当日行程记录等功能。根据你选定的旅行日期范围，滑动切换不同天数的旅行记录。
  -PostTrip
  旅行结束后复盘页面，用于账单汇总、数据导出、历史旅行记录查看。
  -Preparation
  旅行前准备界面，可实现旅行预算设置、开销统计、出行交通信息填写功能。
-TravelMinimalApp
整个iOS项目的程序入口主文件，负责全局数据初始化、根页面挂载、全局环境配置。

File2-TravelMinimal.xcodeproj
Xcode项目的工程配置文件

pages1-4
上机测试展示界面
