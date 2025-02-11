package controller

import (
	"github.com/gin-gonic/gin"
	"gorm.io/gorm"

	"bridge-history-api/internal/logic"
	"bridge-history-api/internal/types"
)

// BatchController contains the query claimable txs service
type BatchController struct {
	batchLogic *logic.BatchLogic
}

// NewBatchController return NewBatchController instance
func NewBatchController(db *gorm.DB) *BatchController {
	return &BatchController{
		batchLogic: logic.NewBatchLogic(db),
	}
}

// GetWithdrawRootByBatchIndex defines the http get method behavior
func (b *BatchController) GetWithdrawRootByBatchIndex(ctx *gin.Context) {
	var req types.QueryByBatchIndexRequest
	if err := ctx.ShouldBind(&req); err != nil {
		types.RenderJSON(ctx, types.ErrParameterInvalidNo, err, nil)
		return
	}
	result, err := b.batchLogic.GetWithdrawRootByBatchIndex(ctx, req.BatchIndex)
	if err != nil {
		types.RenderJSON(ctx, types.ErrGetWithdrawRootByBatchIndexFailure, err, nil)
		return
	}

	types.RenderJSON(ctx, types.Success, nil, result)
}
