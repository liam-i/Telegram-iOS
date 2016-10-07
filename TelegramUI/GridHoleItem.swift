import Foundation
import Display
import AsyncDisplayKit

class GridHoleItem: GridItem {
    func node(layout: GridNodeLayout) -> GridItemNode {
        return GridHoleItemNode()
    }
}

class GridHoleItemNode: GridItemNode {
    private let activityIndicatorView: UIActivityIndicatorView
    
    override init() {
        self.activityIndicatorView = UIActivityIndicatorView(activityIndicatorStyle: .gray)
        
        super.init()
        
        self.view.addSubview(self.activityIndicatorView)
        self.activityIndicatorView.startAnimating()
    }
    
    override func layout() {
        super.layout()
        
        let size = self.bounds.size
        let activityIndicatorSize = self.activityIndicatorView.bounds.size
        self.activityIndicatorView.frame = CGRect(origin: CGPoint(x: floor((size.width - activityIndicatorSize.width) / 2.0), y: floor((size.height - activityIndicatorSize.height) / 2.0)), size: activityIndicatorSize)
    }
}
