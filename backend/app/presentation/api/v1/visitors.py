from fastapi import APIRouter, Depends, HTTPException, Request, status
from app.application.dtos.schemas import VisitorRegisterRequest, VisitorResponse
from app.application.use_cases.visitor_use_cases import RegisterVisitorUseCase
from app.infrastructure.repositories.sqlalchemy_repositories import SqlAlchemyVisitorRepository
from app.presentation.dependencies.auth import get_visitor_repo

router = APIRouter(prefix="/visitors", tags=["Visitors"])

@router.post("/register", response_model=VisitorResponse, status_code=status.HTTP_201_CREATED)
def register_visitor(
    request: Request,
    payload: VisitorRegisterRequest,
    visitor_repo: SqlAlchemyVisitorRepository = Depends(get_visitor_repo),
):
    """
    Registers a new visitor with their name and optional email address.
    Returns a cryptographically secure 256-bit session token.
    Allows returning visitors to view and manage their uploads without passwords.
    """
    try:
        client_ip = request.client.host if request.client else None
        use_case = RegisterVisitorUseCase(visitor_repo)
        visitor = use_case.execute(
            name=payload.name,
            email=payload.email,
            ip_address=client_ip,
        )
        return VisitorResponse(
            id=visitor.id,
            name=visitor.name,
            email=visitor.email,
            session_token=visitor.session_token,
            created_at=visitor.created_at,
        )
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
