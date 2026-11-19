"""Add show_qr_code and visitor_portal_url to slideshow_settings

Revision ID: d48f71a9b201
Revises: c15e93b4660b
Create Date: 2026-11-18 21:55:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

revision: str = 'd48f71a9b201'
down_revision: Union[str, Sequence[str], None] = 'c15e93b4660b'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

def upgrade() -> None:
    with op.batch_alter_table('slideshow_settings', schema=None) as batch_op:
        batch_op.add_column(sa.Column('show_qr_code', sa.Boolean(), server_default='1', nullable=False))
        batch_op.add_column(sa.Column('visitor_portal_url', sa.String(255), nullable=True))

def downgrade() -> None:
    with op.batch_alter_table('slideshow_settings', schema=None) as batch_op:
        batch_op.drop_column('visitor_portal_url')
        batch_op.drop_column('show_qr_code')
