//
//  ViewController.swift
//  JWTextView
//
//  Created by 王嘉宁 on 12/30/2020.
//  Copyright (c) 2020 王嘉宁. All rights reserved.
//

import UIKit
import JWTextView

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        var textConfig = JWTextViewTextConfig()
        textConfig.content = "测试文本测试文本测试文本测试文本测试文本"
        textConfig.textColor = UIColor.red
        textConfig.fontSize = 16
        textConfig.width = 200
        
        var linkConfig = JWLinkTextConfig()
        linkConfig.content = "链接内容"
        linkConfig.textColor = UIColor.blue
        linkConfig.link = "https://www.baidu.com"
        
        let imageConfig = JWImageViewConfig()
        
        var textConfig1 = JWTextViewTextConfig()
        textConfig1.content = "测试文本测试文本测试文本测试文本测试文本"
        textConfig1.textColor = UIColor.red
        textConfig1.fontSize = 16
        textConfig1.width = 200
        
        let textView = JWTextView(frame: CGRect(x: 16, y: 100, width: 200, height: 200))
        textView.config.width = 200
        textView.backgroundColor = .clear
        view.addSubview(textView)
        
        textView.textConfigs = [textConfig, linkConfig, textConfig1]
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

